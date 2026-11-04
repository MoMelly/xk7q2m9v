import Foundation

/// 模型连接参数。Key 不在这里——它只在 Keychain 里路过一下，
/// 拼进请求头之后就不再被持有。
struct LLMConfig: Equatable {
    var baseURL: String
    var model: String
    var apiKey: String

    /// 硅基流动的 OpenAI 兼容端点。国内直连可用。
    static let defaultBaseURL = "https://api.siliconflow.cn/v1"
    static let defaultModel = "deepseek-ai/DeepSeek-V4-Flash"

    /// 去掉末尾斜杠，避免拼出 `//chat/completions`。
    var normalizedBaseURL: String {
        baseURL.hasSuffix("/") ? String(baseURL.dropLast()) : baseURL
    }
}

enum LLMError: LocalizedError {
    case missingKey
    case invalidURL(String)
    case invalidResponse
    case http(status: Int, body: String)

    var errorDescription: String? {
        switch self {
        case .missingKey:
            return "还没填 API Key。点右上角齿轮填一个。"
        case .invalidURL(let raw):
            return "接口地址不对：\(raw)"
        case .invalidResponse:
            return "服务器返回了无法识别的内容。"
        case .http(let status, let body):
            let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
            let preview = trimmed.count > 300 ? String(trimmed.prefix(300)) + "…" : trimmed
            return "请求失败（HTTP \(status)）\n\(preview)"
        }
    }
}
