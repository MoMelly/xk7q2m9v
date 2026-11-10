import Foundation

/// 模型回复拆解。
///
/// 群聊里模型会输出「阿岚：……」「柏川：……」这种多行文本，界面要把它拆成
/// 多个带名字的气泡；旁白（整段被括号包住）则渲染成斜体灰字，不套气泡。
/// 解析放在 Domain 层，因为它决定的是「一段文本由几条发言构成」，属于业务规则。
enum ReplyParser {
    struct Line {
        let speaker: String?
        let text: String
        let isNarration: Bool
    }

    /// 括号旁白：全角、半角都认，允许首尾空白。
    static func isNarration(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return false }
        let pairs: [(Swift.Character, Swift.Character)] = [("（", "）"), ("(", ")"), ("【", "】")]
        for (open, close) in pairs {
            if trimmed.first == open && trimmed.last == close { return true }
        }
        return false
    }

    /// 剥掉最外层那对括号。
    ///
    /// 提示词里让模型用括号写旁白，是为了让它自己分得清「这是在叙事」；
    /// 落到界面上那对括号就是多余的了——正文直接用衬线斜体排，
    /// 再套一层括号会读成「有人在念括号」。
    static func stripBrackets(_ text: String) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 2 else { return trimmed }
        let pairs: [(Swift.Character, Swift.Character)] = [("（", "）"), ("(", ")"), ("【", "】")]
        for (open, close) in pairs where trimmed.first == open && trimmed.last == close {
            return String(trimmed.dropFirst().dropLast())
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return trimmed
    }

    /// 群聊：按行拆，每行尝试解析「名字：内容」。
    /// 认不出发言人的行并入上一条，避免模型偶尔漏写名字就丢内容。
    ///
    /// 整行被括号包住的是旁白。这一条以前漏了：`splitSpeaker` 拆不出名字时
    /// 一律当成「没署名的台词」，于是文游里每一段场景描写都被包上「」当对话显示，
    /// 读起来像有人在念括号。
    static func parseGroup(_ raw: String) -> [Line] {
        let rawLines = raw
            .replacingOccurrences(of: "\r", with: "")
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var result: [Line] = []

        for line in rawLines {
            if let split = splitSpeaker(line) {
                result.append(Line(speaker: split.speaker, text: split.text, isNarration: false))
            } else if isNarration(line) {
                result.append(Line(speaker: nil, text: stripBrackets(line), isNarration: true))
            } else if var last = result.last {
                last = Line(speaker: last.speaker, text: last.text + "\n" + line, isNarration: last.isNarration)
                result[result.count - 1] = last
            } else {
                result.append(Line(speaker: nil, text: line, isNarration: false))
            }
        }

        return result.isEmpty ? [Line(speaker: nil, text: raw, isNarration: false)] : result
    }

    /// 单聊：整段就是一条，只有「整段是括号」才算旁白。
    static func parseSingle(_ raw: String) -> [Line] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        if isNarration(trimmed) {
            return [Line(speaker: nil, text: stripBrackets(trimmed), isNarration: true)]
        }
        return [Line(speaker: nil, text: trimmed, isNarration: false)]
    }

    /// 「名字：内容」，名字最多 12 个字符，且不能含标点，防止把「他说：」误判成发言人。
    private static func splitSpeaker(_ line: String) -> (speaker: String, text: String)? {
        guard let idx = line.firstIndex(where: { $0 == "：" || $0 == ":" }) else { return nil }
        let name = String(line[line.startIndex..<idx]).trimmingCharacters(in: .whitespaces)
        let body = String(line[line.index(after: idx)...]).trimmingCharacters(in: .whitespaces)

        guard !name.isEmpty, name.count <= 12, !body.isEmpty else { return nil }
        let forbidden = CharacterSet(charactersIn: "，。！？、,.!?（）()【】「」\"'")
        guard name.rangeOfCharacter(from: forbidden) == nil else { return nil }
        // 名字里不该有空格连接的长句，出现就说明这是正文而不是发言人。
        guard !name.contains("  ") else { return nil }

        return (name, body)
    }
}
