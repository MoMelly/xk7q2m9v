import Foundation

/// 模型连接参数。Key 不在这里——它只在 Keychain 里路过一下，
/// 拼进请求头之后就不再被持有。
struct LLMConfig: Equatable {
    var baseURL: String
    var model: String
    var apiKey: String
    /// 采样温度。角色扮演默认偏高，否则回答会太「正确」、没脾气。
    var temperature: Double = 0.9
    /// 单次回复的硬上限。定得比目标长度宽，避免句子被砍断。
    var maxTokens: Int = 900
    /// 备用 Key，按顺序试。空数组表示不轮换。
    var fallbackKeys: [String] = []

    /// 这一轮实际要试的 Key，主 Key 在前。
    ///
    /// 去重是必要的：用户很容易把同一把 Key 又粘进备用列表，
    /// 那样失败时会对着同一个已经被拒的 Key 再试一次，白等一个往返。
    var attemptKeys: [String] {
        var seen: Set<String> = []
        var result: [String] = []
        for raw in [apiKey] + fallbackKeys {
            let key = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(key)
        }
        return result
    }

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

    /// 这个错误换一把 Key 有没有意义。
    ///
    /// 只看 401 / 402 / 403 / 429：这四个是「这把 Key 不行 / 额度到头 / 被限流」。
    /// 500 和超时换 Key 没用，那是服务端自己的事，重试只会把等待时间翻倍。
    var isKeyRejection: Bool {
        switch self {
        case .missingKey:
            return true
        case .http(let status, _):
            return [401, 402, 403, 429].contains(status)
        case .invalidURL, .invalidResponse:
            return false
        }
    }
}
