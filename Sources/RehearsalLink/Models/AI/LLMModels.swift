import Foundation

/// サポートするAIプロバイダー
enum LLMProvider: String, Codable, CaseIterable, Identifiable {
    case openai = "OpenAI"
    case anthropic = "Anthropic"
    case gemini = "Google Gemini"

    var id: String {
        rawValue
    }
}

/// AIモデルの定義
struct LLMModel: Identifiable, Codable, Hashable {
    let id: String
    let name: String
    let provider: LLMProvider
    let contextWindow: Int

    static let gpt4o = LLMModel(id: "gpt-4o", name: "GPT-4o", provider: .openai, contextWindow: 128_000)
    static let gpt4oMini = LLMModel(id: "gpt-4o-mini", name: "GPT-4o Mini", provider: .openai, contextWindow: 128_000)

    static let claude46Opus = LLMModel(id: "claude-opus-4-6", name: "Claude 4.6 Opus", provider: .anthropic, contextWindow: 400_000)
    static let claude45Sonnet = LLMModel(id: "claude-sonnet-4-5-20250929", name: "Claude 4.5 Sonnet", provider: .anthropic, contextWindow: 400_000)
    static let claude45Haiku = LLMModel(id: "claude-haiku-4-5-20251001", name: "Claude 4.5 Haiku", provider: .anthropic, contextWindow: 400_000)

    static let gemini15Pro = LLMModel(id: "gemini-1.5-pro", name: "Gemini 1.5 Pro", provider: .gemini, contextWindow: 1_000_000)
    static let gemini15Flash = LLMModel(id: "gemini-1.5-flash", name: "Gemini 1.5 Flash", provider: .gemini, contextWindow: 1_000_000)

    static var allModels: [LLMModel] {
        [.gpt4o, .gpt4oMini, .claude46Opus, .claude45Sonnet, .claude45Haiku, .gemini15Pro, .gemini15Flash]
    }
}

/// AI処理のリクエスト
struct LLMRequest {
    let prompt: String
    let systemPrompt: String?
    let model: LLMModel
    let temperature: Float
    let maxTokens: Int?

    init(prompt: String,
         systemPrompt: String? = nil,
         model: LLMModel = .gpt4oMini,
         temperature: Float = 0.7,
         maxTokens: Int? = nil) {
        self.prompt = prompt
        self.systemPrompt = systemPrompt
        self.model = model
        self.temperature = temperature
        self.maxTokens = maxTokens
    }
}

/// AI処理のレスポンス
struct LLMResponse {
    let text: String
    let usage: LLMUsage?
}

/// トークン使用量
struct LLMUsage: Codable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int
}

/// LLM関連のエラー
enum LLMError: Error, LocalizedError {
    case invalidAPIKey
    case networkError(Error)
    case apiError(status: Int, message: String)
    case decodingError(Error)
    case unknownError(String)

    var errorDescription: String? {
        switch self {
        case .invalidAPIKey:
            return "APIキーが無効です。"
        case let .networkError(error):
            return "ネットワークエラーが発生しました: \(error.localizedDescription)"
        case let .apiError(status, message):
            return "APIエラー (\(status)): \(message)"
        case let .decodingError(error):
            return "レスポンスの解析に失敗しました: \(error.localizedDescription)"
        case let .unknownError(message):
            return "不明なエラーが発生しました: \(message)"
        }
    }
}
