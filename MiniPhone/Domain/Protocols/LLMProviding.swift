import Foundation

/// 模型网关的抽象。Domain 层只认这个协议，不认具体是哪家接口。
/// 换供应商（硅基流动 / OpenAI / 本地 Ollama）只改 Data 层的实现。
protocol LLMProviding: AnyObject {
    /// 流式逐段返回增量文本。调用方拿到片段立刻上屏。
    func streamChat(_ messages: [ChatMessage]) -> AsyncThrowingStream<String, Error>
}
