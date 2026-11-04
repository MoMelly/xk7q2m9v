import Foundation

/// OpenAI 兼容接口的流式客户端。
/// 只依赖 URLSession，不引第三方网络库——这层薄，出问题能一分钟定位。
final class OpenAICompatibleClient: LLMProviding {
    private let config: LLMConfig
    private let session: URLSession

    init(config: LLMConfig, session: URLSession = .shared) {
        self.config = config
        self.session = session
    }

    func streamChat(_ messages: [ChatMessage]) -> AsyncThrowingStream<String, Error> {
        let config = self.config
        let session = self.session

        return AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let request = try Self.makeRequest(messages: messages, config: config)
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
                        if let piece = Self.decodeDelta(payload), !piece.isEmpty {
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

    // MARK: - Request

    private static func makeRequest(
        messages: [ChatMessage],
        config: LLMConfig
    ) throws -> URLRequest {
        let trimmedKey = config.apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedKey.isEmpty else { throw LLMError.missingKey }

        let endpoint = config.normalizedBaseURL + "/chat/completions"
        guard let url = URL(string: endpoint) else {
            throw LLMError.invalidURL(config.baseURL)
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 120
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")

        let body = RequestBody(
            model: config.model,
            messages: messages.map {
                RequestBody.Message(role: $0.role.rawValue, content: $0.text)
            },
            stream: true
        )
        request.httpBody = try JSONEncoder().encode(body)

        AppLog.network.debug("POST \(url.absoluteString, privacy: .public) model=\(config.model, privacy: .public)")
        return request
    }

    // MARK: - SSE decoding

    private struct RequestBody: Encodable {
        struct Message: Encodable {
            let role: String
            let content: String
        }

        let model: String
        let messages: [Message]
        let stream: Bool
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

    private static func decodeDelta(_ json: String) -> String? {
        guard let data = json.data(using: .utf8) else { return nil }
        guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: data) else {
            return nil
        }
        return chunk.choices.first?.delta?.content
    }
}
