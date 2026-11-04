import Foundation

/// OpenAI 兼容接口的客户端。
/// 只依赖 URLSession，不引第三方网络库——这层薄，出问题能一分钟定位。
final class OpenAICompatibleClient: LLMProviding {
    private let config: LLMConfig
    private let session: URLSession

    init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    // MARK: - 流式

    func streamChat(_ messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let config = self.config
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                // 一个请求复用同一个 decoder。之前是每解析一行 new 一个，
                // 一次回复上百行就是上百次分配，白花的。
                let decoder = JSONDecoder()

                do {
                    let request = try Self.makeRequest(messages: messages, config: config, stream: true)
                    let (bytes, response) = try await session.bytes(for: request)

                    guard let http = response as? HTTPURLResponse else {
                        throw LLMError.invalidResponse
                    }

                    guard (200..<300).contains(http.statusCode) else {
                        var body = ""
                        for try await line in bytes.lines {
                            body += line
                            body += "\n"
                        }
                        throw LLMError.http(status: http.statusCode, body: body)
                    }

                    for try await line in bytes.lines {
                        guard line.hasPrefix("data:") else { continue }
                        let payload = String(line.dropFirst(5))
                            .trimmingCharacters(in: .whitespaces)
                        if payload.isEmpty { continue }
                        if payload == "[DONE]" { break }
                        if let piece = Self.decodeDelta(payload, using: decoder), !piece.isEmpty {
                            continuation.yield(piece)
                        }
                    }

                    continuation.finish()
                } catch let error as URLError where error.code == .cancelled {
                    continuation.finish()
                } catch is CancellationError {
                    continuation.finish()
                } catch {
                    AppLog.network.error("stream failed: \(error.localizedDescription, privacy: .public)")
                    continuation.finish(throwing: error)
                }
            }

            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    // MARK: - 一次性

    func complete(_ messages: [ChatMessage]) async throws -> String {
        let request = try Self.makeRequest(messages: messages, config: config, stream: false)
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw LLMError.invalidResponse
        }

        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw LLMError.http(status: http.statusCode, body: body)
        }

        guard let decoded = try? JSONDecoder().decode(CompletionResponse.self, from: data) else {
            throw LLMError.invalidResponse
        }

        let text = decoded.choices.first?.message?.content ?? ""
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw LLMError.invalidResponse
        }
        return text
    }

    // MARK: - Request

    private static func makeRequest(
        messages: [ChatMessage],
        config: LLMConfig,
        stream: Bool
    ) throws -> URLRequest {
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw LLMError.missingKey }

        let endpoint = config.normalizedBaseURL + "/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = stream ? 120 : 60
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue(stream ? "text/event-stream" : "application/json", forHTTPHeaderField: "Accept")

        let body = RequestBody(
            model: config.model,
            messages: messages.map {
                RequestBody.Message(role: $0.role.rawValue, content: $0.text)
            },
            stream: stream,
            temperature: config.temperature,
            maxTokens: config.maxTokens
        )
        request.httpBody = try JSONEncoder().encode(body)

        AppLog.network.debug("POST \(url.absoluteString, privacy: .public) model=\(config.model, privacy: .public) stream=\(stream)")
        return request
    }

    // MARK: - 解码

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let stream: Bool
        let temperature: Double
        let maxTokens: Int

        enum CodingKeys: String, CodingKey {
            case model
            case messages
            case stream
            case temperature
            case maxTokens = "max_tokens"
        }
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }

            let delta: Delta?
        }

        let choices: [Choice]
    }

    private struct CompletionResponse: Decodable {
        struct Choice: Decodable {
            struct Message: Decodable {
                let content: String?
            }

            let message: Message?
        }

        let choices: [Choice]
    }

    private static func decodeDelta(_ json: String, using decoder: JSONDecoder) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let chunk = try? decoder.decode(StreamChunk.self, from: data) else {
            return nil
        }
        return chunk.choices.first?.delta?.content
    }
}
