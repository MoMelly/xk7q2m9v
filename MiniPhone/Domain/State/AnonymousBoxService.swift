import Foundation
import Observation

/// 让角色回答一个匿名问题。
///
/// 提示词里刻意不告诉他这是谁问的，也不提他是被测试的程序——
/// 匿名提问箱的味道就在这儿：对面看不见，他可以不必照顾你的心情。
@Observable
@MainActor
final class AnonymousBoxService {
    static let shared = AnonymousBoxService()

    /// 正在作答的问题 id。
    private(set) var answering: Set<UUID> = []

    func isAnswering(_ id: UUID) -> Bool { answering.contains(id) }

    /// 返回 nil 表示成功，否则是给用户看的失败原因。
    func answer(
        questionID: UUID,
        question: String,
        character: Companion,
        settings: SettingsStore
    ) async -> String? {
        guard !answering.contains(questionID) else { return nil }
        guard settings.isConfigured else {
            return "还没填 API Key。点桌面上的设置填一个。"
        }

        answering.insert(questionID)
        defer { answering.remove(questionID) }

        let world = WorldStore.shared
        let person = world.state.person(named: character.name)
        var memory: [String] = []
        if let summary = person?.summary.trimmingCharacters(in: .whitespacesAndNewlines),
           !summary.isEmpty {
            memory.append(summary)
        }
        memory.append(contentsOf: (person?.facts.suffix(5) ?? []).map { "- \($0.text)" })

        let prompt = PromptBuilder.anonymousAnswerPrompt(
            character: character,
            memoryLines: memory,
            question: question
        )

        let client = OpenAICompatibleClient(config: settings.config)
        do {
            let raw = try await client.complete([
                ChatMessage(role: .system, text: PromptBuilder.anonymousAnswerSystem),
                ChatMessage(role: .user, text: prompt)
            ])
            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { return "他这次没答上来。" }
            world.answerQuestion(id: questionID, answer: text)
            return nil
        } catch {
            AppLog.ui.error("提问箱作答失败: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }
}
