import Foundation

enum OpenAIConfig {
    static var apiKey: String {
        (Bundle.main.object(forInfoDictionaryKey: "OPENAI_API_KEY") as? String) ?? ""
    }
    static let baseURL = URL(string: "https://api.openai.com/v1/responses")!
    static let model   = "gpt-5"   // ← переключаемся на GPT-5
}
