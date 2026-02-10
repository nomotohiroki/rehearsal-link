import Foundation

/// AI設定（APIキー、モデルID等）を管理するサービス
@MainActor
class LLMConfigurationService: ObservableObject {
    static let shared = LLMConfigurationService()

    @Published var selectedProvider: LLMProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "llm_selected_provider") }
    }

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: "llm_selected_provider") ?? LLMProvider.openai.rawValue
        selectedProvider = LLMProvider(rawValue: providerRaw) ?? .openai
    }

    func getAPIKey(for provider: LLMProvider) -> String {
        let key = UserDefaults.standard.string(forKey: "llm_api_key_\(provider.rawValue)") ?? ""
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setAPIKey(_ key: String, for provider: LLMProvider) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedKey, forKey: "llm_api_key_\(provider.rawValue)")
        objectWillChange.send()
    }

    func getModelID(for provider: LLMProvider) -> String {
        let defaultID: String
        switch provider {
        case .openai: defaultID = "gpt-4o-mini"
        case .anthropic: defaultID = "claude-3-5-sonnet-latest"
        case .gemini: defaultID = "gemini-2.0-flash-exp"
        }
        return UserDefaults.standard.string(forKey: "llm_model_id_\(provider.rawValue)") ?? defaultID
    }

    func setModelID(_ id: String, for provider: LLMProvider) {
        let trimmedID = id.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedID, forKey: "llm_model_id_\(provider.rawValue)")
        objectWillChange.send()
    }

    /// 現在の設定に基づいてLLMサービスインスタンスを生成します
    func makeService() -> (any LLMServiceProtocol)? {
        let apiKey = getAPIKey(for: selectedProvider)
        guard !apiKey.isEmpty else { return nil }

        switch selectedProvider {
        case .openai:
            return OpenAIService(apiKey: apiKey)
        case .anthropic:
            return AnthropicService(apiKey: apiKey)
        case .gemini:
            return GeminiService(apiKey: apiKey)
        }
    }

    /// 現在選択されているプロバイダーのモデル情報を取得（互換性維持のため）
    func getSelectedModel() -> LLMModel {
        let provider = selectedProvider
        let id = getModelID(for: provider)
        return LLMModel(id: id, name: id, provider: provider, contextWindow: 128_000)
    }
}
