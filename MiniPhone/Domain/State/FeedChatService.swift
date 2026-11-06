import Foundation
import Observation

/// 生成结果。不用 Swift.Result：它的 Failure 必须遵守 Error，
/// 这里只想带一句能直接给用户看的话。
enum FeedChatOutcome {
    case success(String)
    case failure(String)
}

/// 私信 / 转帖对话里的回复生成。
///
/// 不复用 ChatViewModel：那边会给回复挂刷新 meta、按主聊天的规则拆群聊和旁白。
/// 这里只生成一句话，写库交给界面层——Domain 层不依赖 SwiftData。
/// 历史仍从 Companion.messages 按 thread 取，所以记忆是同一份。
@Observable
@MainActor
final class FeedChatService {
    static let shared = FeedChatService()

    private(set) var replying: Set<String> = []

    func isReplying(_ item: FeedInboxItem) -> Bool {
        replying.contains(item.threadID.uuidString)
    }

    /// 用户那句已经由界面层写进库了，这里只读历史、生成回复。
    func generateReply(
        to item: FeedInboxItem,
        character: Companion,
        settings: SettingsStore,
        userName: String? = nil
    ) async -> FeedChatOutcome {
        guard settings.isConfigured else {
            return .failure("还没填 API Key。点桌面上的设置填一个。")
        }
        let key = item.threadID.uuidString
        guard !replying.contains(key) else {
            return .failure("正在回复中，稍等一下。")
        }

        replying.insert(key)
        defer { replying.remove(key) }

        let world = WorldStore.shared
        let system = PromptBuilder.feedChatSystem(
            character: character,
            item: item,
            activityLines: PromptBuilder.feedActivityLines(
                state: world.state,
                characterName: character.name
            ),
            userName: userName
        )

        let history = character.messages
            .filter { $0.threadRaw == key }
            .sorted { $0.createdAt < $1.createdAt }
            .suffix(20)

        var request: [ChatMessage] = [ChatMessage(role: .system, text: system)]
        request.append(contentsOf: history.map { $0.asChatMessage })

        let client = OpenAICompatibleClient(config: settings.config)
        do {
            let rawReply = try await client.complete(request)
            let reply = rawReply.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !reply.isEmpty else { return .failure("模型这次什么都没说。") }
            return .success(String(reply.prefix(1_200)))
        } catch {
            AppLog.ui.error("私信回复失败: \(error.localizedDescription, privacy: .public)")
            return .failure(error.localizedDescription)
        }
    }
}
