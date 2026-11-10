import Foundation
import Observation

/// 角色自己在西瓜皮上发起一次触达。
///
/// 界面上没有任何「让 TA 发条私信」的按钮，也没有待确认状态：
/// 这里由模型二选一（发私信 / 转帖子），结果直接落成一条 inbox。
/// 冷启动和刷新完成后各调一次，六小时内不重复打扰。
@Observable
@MainActor
final class ProactiveFeedService {
    static let shared = ProactiveFeedService()

    private(set) var isDelivering = false

    private struct Draft {
        let kind: FeedInboxKind
        let text: String
        let note: FeedNote?
    }

    /// 返回新落下的来件；开场白写进角色消息表由界面层做，Domain 层不碰 SwiftData。
    func deliverIfDue(character: Companion, settings: SettingsStore) async -> FeedInboxItem? {
        let world = WorldStore.shared
        // 限流按人算。用全站最近一条来限的话，一个人刚发过，
        // 其他角色就全被按住了，永远不会有人轮上。
        let last = world.state.feedInbox
            .filter { $0.companionName == character.name }
            .map(\.createdAt)
            .max()
        if let last, Date().timeIntervalSince(last) < 6 * 3_600 { return nil }
        return await deliver(character: character, settings: settings)
    }

    func deliver(character: Companion, settings: SettingsStore) async -> FeedInboxItem? {
        guard !isDelivering, settings.isConfigured else { return nil }
        isDelivering = true
        defer { isDelivering = false }

        let world = WorldStore.shared
        let notes = Array(
            world.state.feed
                .sorted { $0.postedAt > $1.postedAt }
                .prefix(6)
        )
        let activity = PromptBuilder.feedActivityLines(
            state: world.state,
            characterName: character.name
        )

        let prompt = PromptBuilder.proactiveFeedPrompt(
            character: character,
            notes: notes,
            activityLines: activity
        )
        let client = OpenAICompatibleClient(config: settings.config)

        do {
            let raw = try await client.complete([
                ChatMessage(role: .system, text: PromptBuilder.proactiveFeedSystem),
                ChatMessage(role: .user, text: prompt)
            ])
            guard let draft = parse(raw, notes: notes) else { return nil }
            return write(draft, character: character)
        } catch {
            AppLog.ui.error("主动私信失败: \(error.localizedDescription, privacy: .public)")
            return nil
        }
    }

    private func write(_ draft: Draft, character: Companion) -> FeedInboxItem {
        let threadID = UUID()
        let item = FeedInboxItem(
            id: UUID(),
            kind: draft.kind,
            companionUID: character.uid.uuidString,
            companionName: character.name,
            noteID: draft.note?.id,
            noteTitle: draft.note?.title ?? "",
            noteBody: draft.note?.body ?? "",
            noteTag: draft.note?.tag ?? "",
            coverSeed: draft.note?.coverSeed ?? 0,
            message: draft.text,
            createdAt: Date(),
            isRead: false,
            threadID: threadID
        )
        WorldStore.shared.deliverFeedInbox(item)

        return item
    }

    /// 模型偶尔会裹一层代码块或多说一句，取花括号里那段即可；
    /// 完全不是 JSON 时退化成一条私信，宁可少一种版式也不要丢掉这次触达。
    private func parse(_ raw: String, notes: [FeedNote]) -> Draft? {
        let cleaned = raw
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let fallback = String(cleaned.prefix(120))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}"),
              let data = String(cleaned[start...end]).data(using: .utf8),
              let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return fallback.isEmpty ? nil : Draft(kind: .directMessage, text: fallback, note: nil)
        }

        let text = (object["text"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !text.isEmpty else { return nil }

        guard (object["kind"] as? String) == "share" else {
            return Draft(kind: .directMessage, text: String(text.prefix(120)), note: nil)
        }
        let index = (object["note"] as? Int) ?? 0
        guard index >= 1, index <= notes.count else {
            return Draft(kind: .directMessage, text: String(text.prefix(120)), note: nil)
        }
        return Draft(kind: .postShare, text: String(text.prefix(120)), note: notes[index - 1])
    }
}
