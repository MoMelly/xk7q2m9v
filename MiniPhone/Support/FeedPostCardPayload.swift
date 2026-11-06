import Foundation

/// 分享到私聊里的帖子小卡片。
///
/// 卡片本身是一条消息，但借 `StoredMessage.text` 存：特殊前缀 + 一行 JSON。
/// 这样不用给 SwiftData 模型加第三种消息类型，也不用给 WorldState 加字段，
/// 老存档照样能解。渲染层认前缀，发给模型时先翻成一句人话。
struct FeedPostCardPayload: Codable {
    static let prefix = "[[postcard]]"

    var noteID: String
    var title: String
    var body: String
    var tag: String
    var coverSeed: Int

    func encoded() -> String {
        guard let data = try? JSONEncoder().encode(self),
              let json = String(data: data, encoding: .utf8) else { return "" }
        return Self.prefix + json
    }

    static func decode(_ text: String) -> FeedPostCardPayload? {
        guard text.hasPrefix(prefix) else { return nil }
        let json = String(text.dropFirst(prefix.count))
        guard let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(FeedPostCardPayload.self, from: data)
    }

    /// 历史消息进提示词之前过一遍，别让模型读 JSON。
    static func readable(_ text: String) -> String {
        guard let card = decode(text) else { return text }
        let tag = card.tag.isEmpty ? "" : " #\(card.tag)"
        return "[分享了一篇笔记：《\(card.title)》\(tag)]"
    }
}
