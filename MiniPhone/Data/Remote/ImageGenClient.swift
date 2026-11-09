import Foundation
import UIKit

/// 文生图接口。
///
/// 和聊天共用同一个 `baseURL` 和同一套 Key，但**请求体不是同一套**：
/// OpenAI 那边要 `size` / `n`，硅基流动那边要 `image_size` / `batch_size`，
/// 而且两边都不认识对方的字段（OpenAI 会直接 400 说参数不认识）。
/// 所以这里按「先硅基、后 OpenAI」试两次，只在 400 这种参数级错误上换一次写法，
/// 401/429 照旧走换 Key 的路子。
///
/// 返回 `UIImage` 而不是 URL：硅基流动生成的 url 一小时就失效，
/// 存下来一个过期链接等于什么都没存。
struct ImageGenClient {
    let config: LLMConfig
    let model: String

    enum GenError: LocalizedError {
        case noImage
        case decodeFailed
        case badResponse

        var errorDescription: String? {
            switch self {
            case .noImage:
                return "接口没有返回图片。模型名对不对？"
            case .decodeFailed:
                return "图片下载下来了，但解不开。"
            case .badResponse:
                return "生图接口返回了无法识别的内容。"
            }
        }
    }

    /// 一张 1024 的方图。西瓜皮的封面是竖的，铺满时居中裁一刀，
    /// 比生成竖图省一半 token，也不影响观感——构图本来就该是一眼看懂的东西。
    private static let imageSize = "1024x1024"

    func generate(prompt: String) async throws -> UIImage {
        var lastError: Error = LLMError.missingKey

        for key in config.attemptKeys {
            do {
                return try await once(prompt: prompt, key: key)
            } catch {
                lastError = error
                if let llm = error as? LLMError, llm.isKeyRejection {
                    continue
                }
                throw error
            }
        }
        throw lastError
    }

    private func once(prompt: String, key: String) async throws -> UIImage {
        do {
            return try await send(prompt: prompt, key: key, openAIStyle: false)
        } catch LLMError.http(let status, let body) where status == 400 {
            // 参数不认识才算「换一种写法」，别的 400（比如内容被拒）重试也没用。
            let lower = body.lowercased()
            guard lower.contains("unknown") || lower.contains("unrecognized")
                    || lower.contains("extra") || lower.contains("validation") else {
                throw LLMError.http(status: status, body: body)
            }
            return try await send(prompt: prompt, key: key, openAIStyle: true)
        }
    }

    private func send(prompt: String, key: String, openAIStyle: Bool) async throws -> UIImage {
        guard let url = URL(string: config.normalizedBaseURL + "/images/generations") else {
            throw LLMError.invalidURL(config.baseURL)
        }

        var payload: [String: Any] = [
            "model": model,
            "prompt": prompt
        ]
        if openAIStyle {
            payload["n"] = 1
            payload["size"] = Self.imageSize
        } else {
            payload["image_size"] = Self.imageSize
            payload["batch_size"] = 1
            payload["num_inference_steps"] = 20
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 120
        request.httpBody = try JSONSerialization.data(withJSONObject: payload)

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw LLMError.invalidResponse }
        guard (200..<300).contains(http.statusCode) else {
            throw LLMError.http(
                status: http.statusCode,
                body: String(data: data, encoding: .utf8) ?? ""
            )
        }

        if let inline = Self.inlineImage(in: data) { return inline }
        if let remote = Self.remoteURL(in: data) {
            return try await download(remote)
        }
        throw GenError.noImage
    }

    private func download(_ url: URL) async throws -> UIImage {
        let (data, response) = try await URLSession.shared.data(from: url)
        if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
            throw LLMError.http(status: http.statusCode, body: "")
        }
        guard let image = UIImage(data: data) else { throw GenError.decodeFailed }
        return image
    }

    // MARK: - 两种返回形状

    /// `images` 是硅基流动，`data` 是 OpenAI。两边都可能直接给 base64。
    private static func entries(in data: Data) -> [[String: Any]] {
        guard let object = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any] else {
            return []
        }
        let raw = (object["images"] as? [[String: Any]])
            ?? (object["data"] as? [[String: Any]])
            ?? []
        return raw
    }

    private static func inlineImage(in data: Data) -> UIImage? {
        for entry in entries(in: data) {
            guard let base64 = entry["b64_json"] as? String,
                  let raw = Data(base64Encoded: base64),
                  let image = UIImage(data: raw) else { continue }
            return image
        }
        return nil
    }

    private static func remoteURL(in data: Data) -> URL? {
        for entry in entries(in: data) {
            guard let raw = entry["url"] as? String, let url = URL(string: raw) else { continue }
            return url
        }
        return nil
    }
}
