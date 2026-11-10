import Foundation

/// 群聊记忆的分层整理。
///
/// 一段群聊记录里其实有两层东西：群里共同发生了什么（谁跟谁拌了嘴、约了几点、
/// 谁最后没接话），以及每个人自己那一份（他说过什么、被谁的话戳到了）。
///
/// 原来只压成一段、并且挂到群主名下，后果是：群主一个人扛下整个群的记忆，
/// 其他人回到单聊里对群里的事一无所知；而每个成员名下又被塞进同一段摘要，
/// 变成「柏川记得阿岚说过的话」，而且记成自己说的。
///
/// 所以压缩时让模型分层输出，落库时分开写：群那段进 `people[群名]`，
/// 人那段进 `people[人名]`。单聊时靠 `WorldState.groups` 反查把群记忆带上。
enum GroupDigest {

    struct Digest {
        /// 群里共同的那一份。
        var group: String
        /// 每个人各自的那一份。模型漏写某人时这里就没有他，不会硬补。
        var people: [(name: String, text: String)]
    }

    /// 压缩提示词。
    ///
    /// `previous` 是已有的群记忆，明确要求「合成一份」而不是追加：
    /// 摘要是一份快照，追加会让旧内容把新的挤出去。
    static func prompt(
        group: String,
        members: [String],
        previous: String,
        transcript: String
    ) -> String {
        let roster = members.joined(separator: "、")
        let sections = members.map { name in
            """
            【\(name)】
            只写\(name)自己在这场对话里说过、做过、被牵动的事。不要写别人说了什么，
            除非那件事直接落在他身上。三百字以内。
            """
        }.joined(separator: "\n\n")

        var parts: [String] = []
        parts.append("""
        你在整理「\(group)」这个群聊里发生过的事。整理成两份：群里共同的，和每个人各自的。
        群成员：\(roster)
        """)
        parts.append("""
        严格按下面的格式输出，用小标题分节，不要别的内容：
        【群】
        这个群里发生过什么：谁跟谁之间怎样了、一起做了什么、约定了什么、有什么没说完。
        只写事实和气氛，不要写谁「心里想」——那属于各人那一份。

        \(sections)
        """)
        if !previous.isEmpty {
            parts.append("【这个群原有的记忆】\n\(previous)")
        }
        parts.append("【这次的对话】\n\(transcript)")
        parts.append("""
        要求：
        - 第三人称，像一份备忘录。
        - 一律用名字，不要用「他」——名字一含糊，分到个人时就会张冠李戴。
        - 已有的记忆和这次的内容要合成一份完整的，不是往后追加。
        - 没出现过的事不要编。某人这轮没参与，就不写他那一节。
        """)
        return parts.joined(separator: "\n\n")
    }

    /// 解析模型的分节输出。
    ///
    /// 模型没按格式来时整段退回去当群记忆：宁可写得糙，
    /// 也不能让这一轮对话从记忆里漏掉；但绝不往个人名下塞整段。
    static func parse(_ raw: String, members: [String], limit: Int = 1_200) -> Digest {
        let roster = Set(members)
        var group = ""
        var people: [(name: String, text: String)] = []
        var current: String?
        var buffer: [String] = []

        func flush() {
            let text = buffer
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            buffer.removeAll()
            guard !text.isEmpty else { return }
            if current == "群" {
                group = group.isEmpty ? text : group + "\n" + text
            } else if let name = current, roster.contains(name) {
                people.append((name, text))
            }
        }

        let rows = raw
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        for row in rows {
            if let head = header(row.trimmingCharacters(in: .whitespaces)) {
                flush()
                current = (head == "群" || head == "群里") ? "群"
                    : (roster.contains(head) ? head : nil)
            } else if current != nil {
                buffer.append(row)
            }
        }
        flush()

        // 一节都没认出来：整段当群记忆。
        if group.isEmpty, people.isEmpty {
            let whole = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            group = String(whole.suffix(limit))
        }
        // 有分节但没有【群】段：用各人那段拼一份，至少群记忆不为空。
        if group.isEmpty {
            group = people.map { "\($0.name)：\($0.text)" }.joined(separator: "\n")
        }

        return Digest(
            group: String(group.suffix(limit)),
            people: people.map { (name: $0.name, text: String($0.text.suffix(limit))) }
        )
    }

    /// 一行只认「【xxx】」且 xxx 够短。正文里偶尔也会用方括号，
    /// 但很少正好独占一行、又短到像个名字。
    private static func header(_ line: String) -> String? {
        guard line.count >= 3, line.hasPrefix("【"), line.hasSuffix("】") else { return nil }
        let inner = String(line.dropFirst().dropLast()).trimmingCharacters(in: .whitespaces)
        guard !inner.isEmpty, inner.count <= 12 else { return nil }
        return inner
    }
}
