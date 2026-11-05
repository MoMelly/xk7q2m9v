import Foundation
import Observation

/// 让角色写一封信。
///
/// 一次用户动作换一次调用，不做自动触发：信要是「刚好来了」才像信，
/// 每隔几轮冒一封就成了推送。写完落在世界状态里，信件页只读它。
@Observable
@MainActor
final class LetterService {
    static let shared = LetterService()

    /// 正在写的角色（按 uid）。按钮据此转圈并禁用。
    private(set) var writing: Set<String> = []

    func isWriting(_ character: Companion) -> Bool {
        writing.contains(character.uid.uuidString)
    }

    /// 返回 nil 表示写成功，否则是给用户看的失败原因。
    func write(character: Companion, settings: SettingsStore) async -> String? {
        let key = character.uid.uuidString
        guard !writing.contains(key) else { return nil }
        guard settings.isConfigured else {
            return "还没填 API Key。点桌面上的设置填一个。"
        }

        writing.insert(key)
        defer { writing.remove(key) }

        let world = WorldStore.shared
        var memoryLines: [String] = []
        if let person = world.state.person(named: character.name) {
            let summary = person.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            if !summary.isEmpty {
                memoryLines.append(summary)
            }
            memoryLines.append(contentsOf: person.facts.suffix(6).map { "- \($0.text)" })
        }

        let prompt = PromptBuilder.letterPrompt(
            character: character,
            memoryLines: memoryLines
        )

        let client = OpenAICompatibleClient(config: settings.config)

        do {
            let raw = try await client.complete([
                ChatMessage(role: .system, text: PromptBuilder.letterSystem),
                ChatMessage(role: .user, text: prompt)
            ])

            let text = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else {
                return "模型这次什么都没写。"
            }

            let parsed = splitTitleAndBody(text)
            world.appendLetter(from: character.name, title: parsed.title, body: parsed.body)
            return nil
        } catch {
            AppLog.ui.error("写信失败: \(error.localizedDescription, privacy: .public)")
            return error.localizedDescription
        }
    }

    /// 第一行短且不像称呼，就当标题；否则自己起一个。
    private func splitTitleAndBody(_ text: String) -> (title: String, body: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        guard let first = lines.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !first.isEmpty,
              first.count <= 14,
              !first.contains("："), !first.contains(":"),
              !first.contains("，") else {
            return ("写给你的信", text)
        }

        let rest = lines.dropFirst().joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard rest.count >= 20 else {
            return ("写给你的信", text)
        }
        return (first, rest)
    }
}
