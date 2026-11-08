import Foundation

/// 聊天页顶栏那行小字。
///
/// 从 `ChatView` 抽出来的：那个文件已经贴着 600 行上限，凡是能独立成句的
/// 判断都该搬走，不然后面加一个按钮就得先拆一个函数。
enum ChatLabels {
    /// 「自定义 · 在的」「群聊 · 睡了」
    static func subtitle(_ character: Companion, at date: Date) -> String {
        var parts: [String] = [character.preset.displayName]
        if character.isGroup {
            parts.append("群聊")
        }
        parts.append(CharacterClock.isAsleep(character, at: date) ? "睡了" : "在的")
        return parts.joined(separator: " · ")
    }
}
