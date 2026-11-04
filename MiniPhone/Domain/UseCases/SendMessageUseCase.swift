import Foundation

/// 一次对话回合。ViewModel 只通过它接触模型，
/// 以后加"记忆注入""预设装配"都长在这个用例里，不动 UI。
struct SendMessageUseCase {
    private let llm: LLMProviding

    init(llm: LLMProviding) {
        self.llm = llm
    }

    func streamReply(to history: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let payload = history.filter { !$0.text.isEmpty }
        return llm.streamChat(payload)
    }
}
