import Foundation

public struct ChatMessage: Codable {
    public enum Role: String, Codable { case system, user, assistant }
    public let role: Role
    public let content: String

    public init(role: Role, content: String) {
        self.role = role
        self.content = content
    }
}

struct ResponsesRequest: Codable {
    let model: String
    let input: [Message]
    let temperature: Double?      // будем передавать только для моделей, где это поддержано
    let stream: Bool?

    struct Message: Codable {
        let role: String
        let content: String
    }
}


struct ResponsesResponse: Decodable {
    let id: String?
    let output_text: String?
    let output: [OutputItem]?

    struct OutputItem: Decodable {
        let role: String?
        let content: [ContentItem]?
    }
    struct ContentItem: Decodable {
        let type: String?
        let text: String?
    }

    /// Берём текст из output_text, а если пусто — собираем из output.content[].text
    var resolvedText: String? {
        if let t = output_text, !t.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return t
        }
        guard let output else { return nil }
        let pieces = output
            .flatMap { $0.content ?? [] }
            .compactMap { ($0.type == "output_text") ? $0.text : $0.text }
        let joined = pieces.joined()
        return joined.isEmpty ? nil : joined
    }
}
