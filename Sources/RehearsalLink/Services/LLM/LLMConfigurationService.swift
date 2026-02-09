import Foundation

/// AI設定（APIキー、選択中のモデル等）を管理するサービス
@MainActor
class LLMConfigurationService: ObservableObject {
    static let shared = LLMConfigurationService()

    @Published var selectedProvider: LLMProvider {
        didSet { UserDefaults.standard.set(selectedProvider.rawValue, forKey: "llm_selected_provider") }
    }

    @Published var selectedModelId: String {
        didSet { UserDefaults.standard.set(selectedModelId, forKey: "llm_selected_model_id") }
    }

    init() {
        let providerRaw = UserDefaults.standard.string(forKey: "llm_selected_provider") ?? LLMProvider.openai.rawValue
        selectedProvider = LLMProvider(rawValue: providerRaw) ?? .openai

        selectedModelId = UserDefaults.standard.string(forKey: "llm_selected_model_id") ?? LLMModel.gpt4oMini.id
    }

    func getAPIKey(for provider: LLMProvider) -> String {
        // 注意: セキュリティ向上のため、将来的に Keychain への移行を検討してください
        let key = UserDefaults.standard.string(forKey: "llm_api_key_\(provider.rawValue)") ?? ""
        return key.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func setAPIKey(_ key: String, for provider: LLMProvider) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(trimmedKey, forKey: "llm_api_key_\(provider.rawValue)")
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

    func getSelectedModel() -> LLMModel {
        LLMModel.allModels.first { $0.id == selectedModelId } ?? .gpt4oMini
    }
}
