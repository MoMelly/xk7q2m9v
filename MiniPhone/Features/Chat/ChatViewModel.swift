import Foundation
import Observation

/// 聊天状态机：发一句、流式收回来、出错能看见原因。
///
/// 这一层刻意很薄——P2 接数据库和角色记忆时整体替换，不牵动 UI。
@Observable
final class ChatViewModel {
    private(set) var messages: [ChatMessage] = []
    private(set) var isStreaming = false
    private(set) var errorText: String?

    @MainActor
    func send(_ text: String, settings: SettingsStore) async {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isStreaming else { return }

        errorText = nil
        messages.append(ChatMessage(role: .user, text: trimmed))

        // 先插一条空的助手消息占位，流式片段往它身上追加，
        // 这样界面上看到的是「气泡逐渐长出来」而不是最后一次性出现。
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
