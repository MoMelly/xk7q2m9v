import Foundation
import Observation

/// P0 的冒烟测试状态机：发一句、流式收回来、出错能看见原因。
/// 这一层故意很薄——P2 接数据库和记忆时整体替换，不牵动 UI。
@Observable
final class SmokeTestViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false
    private(set) var errorText: String?

    @MainActor
    func send(_ text: String, settings: SettingsStore) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        errorText = nil
        messages.append(ChatMessage(role: .user, text: trimmed))

        let placeholderID = UUID()
        messages.append(ChatMessage(id: placeholderID, role: .assistant, text: ""))

        isStreaming = true
        defer { isStreaming = false }

        let useCase = SendMessageUseCase(
            llm: OpenAICompatibleClient(config: settings.config)
        )
        let history = messages.filter { $0.id != placeholderID }

        do {
            for try await piece in useCase.streamReply(to: history) {
                guard let index = messages.firstIndex(where: { $0.id == placeholderID }) else {
                    continue
                }
                messages[index].text += piece
            }

            if let index = messages.firstIndex(where: { $0.id == placeholderID }),
               messages[index].text.isEmpty {
                messages[index].text = "（一个片段都没收到。模型可能不支持流式，或者中途被掐断了。）"
            }
        } catch {
            if let index = messages.firstIndex(where: { $0.id == placeholderID }) {
                messages.remove(at: index)
            }
            errorText = error.localizedDescription
            AppLog.ui.error("send failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
