import Foundation

/// 从回复文本里挑出 `[表情:名字]`。
///
/// 用标记而不是给消息加字段：模型只会吐文本，加字段得在解析层再猜一遍；
/// 标记还能出现在正文中间，模型偶尔会写「你说得对 [表情:嫌弃]」。
enum StickerTextParser {
    private static let pattern = "\\[表情\\s*[:：]\\s*([^\\]\\n]+)\\]"

    /// 返回去掉标记的正文，和按出现顺序排好的表情名。
    static func parse(_ text: String) -> (body: String, names: [String]) {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return (text, [])
        }

        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let names: [String] = regex.matches(in: text, range: range).compactMap { match in
            guard let sub = Range(match.range(at: 1), in: text) else { return nil }
            let name = String(text[sub]).trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : name
        }

        let cleaned = regex
            .stringByReplacingMatches(in: text, range: range, withTemplate: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return (cleaned, names)
    }
}
