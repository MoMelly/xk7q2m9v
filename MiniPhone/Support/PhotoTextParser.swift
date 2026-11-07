import Foundation

/// 从回复文本里挑出 `[图:说明]`。
///
/// 和表情同一套约定：模型只会吐文本，用标记比给消息加字段省事，
/// 标记还能落在句子中间。说明可以留空，写 `[图]` 就是一张没配字的图。
enum PhotoTextParser {
    /// 冒号后面整段都算说明，所以不用 `+` 卡长度；不写冒号也能匹配。
    private static let pattern = "\\[图\\s*(?:[:：]\\s*([^\\]\\n]*))?\\]"

    /// 返回去掉标记的正文，和按出现顺序排好的说明。
    static func parse(_ text: String) -> (body: String, notes: [String]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, [])
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        // 说明为空也要占位：`[图]` 和 `[图:傍晚]` 是两种情况，
        // 把空的过滤掉会让「一张没配字的图」凭空消失。
        let notes: [String] = regex.matches(in: text, range: range).map { match in
            guard match.numberOfRanges > 1,
                  let sub = Range(match.range(at: 1), in: text) else { return "" }
            return String(text[sub]).trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let cleaned = regex
            .stringByReplacingMatches(in: text, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (cleaned, notes)
    }

    /// 同一个说明永远落到同一张图上：重开对话还是那张，不会每次刷新都换。
    /// 0 是「没有图」的哨兵值，所以最后兜一个 1。
    static func seed(for note: String) -> Int {
        max(1, StableSeed.of("photo:\(note)"))
    }
}
