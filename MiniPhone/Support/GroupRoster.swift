import Foundation

/// 群成员名单的读写。
///
/// 名单存在 `Companion.membersNote` 上，是一串用顿号隔开的名字。提示词、
/// 群记忆、消息头像都按名字找人，所以这里只做翻译，不换存储结构——
/// 换一份结构化的名单，老存档里的群会当场变成空群。
enum GroupRoster {
    /// 从那段文字里拆出名字。逗号、顿号、换行都有人用，三种都当分隔符。
    static func names(from note: String) -> [String] {
        var seen = Set<String>()
        return note
            .split(whereSeparator: { $0 == "," || $0 == "，" || $0 == "、" || $0 == "\n" })
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    /// 写回一段文字。顺序就是界面上排的顺序，加人加在末尾。
    static func note(from names: [String]) -> String {
        var seen = Set<String>()
        return names
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
            .joined(separator: "、")
    }

    /// 这个群里的成员，落到角色上。名单上写了、库里没有的名字会丢掉——
    /// 界面上要画头像，找不到人就没法画。
    static func members(of group: Companion, in roster: [Companion]) -> [Companion] {
        names(from: group.membersNote).compactMap { name in
            roster.first { $0.name == name }
        }
    }
}
