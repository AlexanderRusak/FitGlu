import Foundation

enum AIProviderError: LocalizedError {
    case missingAPIKey
    case http(Int, String)
    case emptyResponse

    var errorDescription: String? {
        switch self {
        case .missingAPIKey: return "Missing OpenAI API key."
        case .http(let code, let body): return "OpenAI HTTP \(code): \(body)"
        case .emptyResponse: return "Empty output_text."
        }
    }
}

final class ChatGPTProvider {

    private lazy var session: URLSession = {
        let cfg = URLSessionConfiguration.ephemeral
        cfg.timeoutIntervalForRequest = 60
        cfg.timeoutIntervalForResource = 60
        return URLSession(configuration: cfg)
    }()

    /// Простой вызов Responses API (без стриминга)
    func send(messages: [ChatMessage], temperature: Double = 0.7) async throws -> String {
        guard !OpenAIConfig.apiKey.isEmpty else { throw AIProviderError.missingAPIKey }

        let isGpt5 = OpenAIConfig.model.lowercased().hasPrefix("gpt-5")

        let reqBody = ResponsesRequest(
            model: OpenAIConfig.model,
            input: messages.map { .init(role: $0.role.rawValue, content: $0.content) },
            temperature: isGpt5 ? nil : temperature,  // ⬅️ для gpt-5 не шлём
            stream: false
        )

        var req = URLRequest(url: OpenAIConfig.baseURL)
        req.httpMethod = "POST"
        req.setValue("Bearer \(OpenAIConfig.apiKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONEncoder().encode(reqBody)

        let (data, resp) = try await session.data(for: req)
        guard let http = resp as? HTTPURLResponse else {
            throw AIProviderError.http(-1, "No HTTPURLResponse")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIProviderError.http(http.statusCode, body)
        }

        let decoded = try JSONDecoder().decode(ResponsesResponse.self, from: data)
        guard let text = decoded.resolvedText else {
            // полезно видеть тело при отладке
            let raw = String(data: data, encoding: .utf8) ?? "<no body>"
            throw AIProviderError.http(http.statusCode, "Empty output_text (raw: \(raw.prefix(300)))")
        }
        return text
    }
}
