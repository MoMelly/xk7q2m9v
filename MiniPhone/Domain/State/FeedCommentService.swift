import Foundation

/// 动态底下的评论。
///
/// 原来只有「我评论」这一半：写完就落库，没有任何人回应。角色那边只靠整页刷新
/// 顺手补 0~2 句，跟我刚才说了什么没关系。这里在我评论之后单独要一轮，
/// 让作者回我、也让在场的人互相接得上。
@MainActor
enum FeedCommentService {
    @discardableResult
    static func reply(to noteID: UUID, settings: SettingsStore) async -> Int {
        let world = WorldStore.shared
        guard settings.isConfigured else { return 0 }
        guard let note = world.state.feed.first(where: { $0.id == noteID }) else { return 0 }

        // 只给最近几条：给多了模型会去接很早以前那句，看起来像没在听人说话。
        let recent = note.comments
            .suffix(6)
            .map { "\($0.authorName)：\($0.text)" }
            .joined(separator: "\n")

        let roster = world.state.people
            .map(\.name)
            .filter { !$0.isEmpty }
            .prefix(6)
            .joined(separator: "、")

        let prompt = """
        一条动态：
        作者：\(note.authorName)
        标题：\(note.title)
        正文：\(note.body)

        底下已有的评论：
        \(recent.isEmpty ? "（还没有）" : recent)

        在场的人：\(roster.isEmpty ? "（没有别的角色）" : roster)

        再补 1~2 条评论：
        - 作者本人要回「我」那一句，用第一人称，别复述正文；
        - 其他在场的人可以回「我」，也可以接作者的话，要能看出是在对话；
        - 每条 30 字以内，口语，不要总结、不要客套；
        - 只输出 JSON：{"comments":[{"author":"名字","text":"内容"}]}
        """

        do {
            let raw = try await OpenAICompatibleClient(config: settings.config).complete([
                ChatMessage(role: .system, text: "你在写动态底下的评论，只输出 JSON。"),
                ChatMessage(role: .user, text: prompt)
            ])
            let items = parse(raw)
            guard !items.isEmpty else { return 0 }
            return append(items, to: noteID, world: world)
        } catch {
            AppLog.ui.error("评论回复失败: \(error.localizedDescription, privacy: .public)")
            return 0
        }
    }

    // MARK: - 解析

    private struct Payload: Decodable {
        struct Item: Decodable {
            let author: String?
            let text: String?
        }

        let comments: [Item]?
    }

    private static func parse(_ raw: String) -> [(author: String, text: String)] {
        // 模型常把 JSON 包在代码块里，先把围栏剥掉。
        var body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let start = body.firstIndex(of: "{"), let end = body.lastIndex(of: "}") {
            body = String(body[start...end])
        }

        guard let data = body.data(using: .utf8),
              let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else { return [] }

        return (payload.comments ?? []).compactMap { item in
            guard let text = item.text?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !text.isEmpty
            else { return nil }
            let author = item.author?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            return (author.isEmpty ? "网友" : author, text)
        }
    }

    private static func append(
        _ items: [(author: String, text: String)],
        to noteID: UUID,
        world: WorldStore
    ) -> Int {
        guard let index = world.state.feed.firstIndex(where: { $0.id == noteID }) else { return 0 }

        var added = 0
        for item in items.prefix(2) {
            world.state.feed[index].comments.append(
                NoteComment(
                    id: UUID(),
                    authorName: String(item.author.prefix(12)),
                    text: String(item.text.prefix(60)),
                    postedAt: Date(),
                    isCharacter: true
                )
            )
            added += 1
        }
        if added > 0 { world.save() }
        return added
    }
}
