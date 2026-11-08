import Foundation

/// 角色自己「知道的东西」：他手机里留过的、他写过的信。
///
/// 查手机那一页的内容全部由模型生成。如果只存在页面上、不反过来喂给聊天，
/// 角色被问「你购物车里那个是什么」就只会答「什么购物车」——那一页就成了
/// 只给玩家看的摆设。这一份是从世界状态里抽出来、压成短句的背景。
///
/// 每条都压到一句话：这块是给模型当底，不是让它照着念清单。
extension WorldStore {
    /// 他那台手机里的东西。只取本人那台：换角色时旧手机不清，认错人比失忆更糟。
    func phoneLines(for owner: String) -> [String] {
        guard !owner.isEmpty, let phone = state.phone, phone.owner == owner else { return [] }
        var lines: [String] = []

        for chat in phone.chats.prefix(3) where !chat.preview.isEmpty {
            let relation = chat.relation.isEmpty ? "" : "（\(chat.relation)）"
            lines.append("微信里跟 \(chat.name)\(relation) 最后一句：\(chat.preview)")
        }

        let captions = phone.album.prefix(4).map(\.caption).filter { !$0.isEmpty }
        if !captions.isEmpty {
            lines.append("相册里最近几张：\(captions.joined(separator: "、"))")
        }

        for note in phone.notes.prefix(2) where !note.title.isEmpty {
            let body = String(note.body.prefix(40))
            lines.append("备忘录「\(note.title)」：\(body)")
        }

        if !phone.shopping.isEmpty {
            let items = phone.shopping.prefix(4).map { "\($0.title) \($0.price)" }
            lines.append("购物车：\(items.joined(separator: "、"))")
        }

        if !phone.history.isEmpty {
            let items = phone.history.prefix(4).map(\.title)
            lines.append("最近搜过：\(items.joined(separator: "、"))")
        }

        if !phone.usage.isEmpty {
            let items = phone.usage.prefix(2).map { "\($0.app) \($0.display)" }
            lines.append("今天用得最多：\(items.joined(separator: "、"))")
        }

        // 只说「瞒着你」那一档。私密那档是他自己收起来的，进提示词只会让模型主动提。
        for secret in phone.secrets where !secret.isPrivate && !secret.title.isEmpty {
            lines.append("没跟他说的事「\(secret.title)」：\(secret.text)")
        }

        return lines
    }

    /// 他写过的信。信是有开头落款、一次写完的东西，角色得记得自己寄过。
    ///
    /// 只留最近三封的标题：正文都在信里，塞进提示词会把对话挤掉，
    /// 模型也容易开始背自己写过的句子。
    func letterLines(for owner: String) -> [String] {
        guard !owner.isEmpty else { return [] }
        let mine = state.letters
            .filter { $0.fromName == owner }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(3)
        guard !mine.isEmpty else { return [] }

        return mine.map { letter in
            let read = letter.isRead ? "他看过了" : "他还没拆"
            return "《\(letter.title)》，\(TimeFormat.callTime(letter.createdAt)) 寄的，\(read)"
        }
    }

    /// 两个字的重合度。中文短句上够用，也不用拉分词。
    static func relevance(_ text: String, focus: String) -> Int {
        let characters = Array(focus)
        guard characters.count >= 3 else { return 0 }
        var grams = Set<String>()
        for index in 0..<(characters.count - 1) {
            grams.insert(String(characters[index...index + 1]))
        }
        return grams.reduce(0) { $0 + (text.contains($1) ? 1 : 0) }
    }
}
