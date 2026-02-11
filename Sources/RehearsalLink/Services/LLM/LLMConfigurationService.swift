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
        let account = "llm_api_key_\(provider.rawValue)"
        let service = "com.rehearsallink.api-keys"

        // Keychainから取得を試みる
        if let key = KeychainHelper.shared.readString(service: service, account: account) {
            return key.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // UserDefaultsからの移行パス
        let key = UserDefaults.standard.string(forKey: account) ?? ""
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)

        if !trimmedKey.isEmpty {
            // Keychainに保存
            KeychainHelper.shared.save(trimmedKey, service: service, account: account)
            // UserDefaultsから削除
            UserDefaults.standard.removeObject(forKey: account)
        }

        return trimmedKey
    }

    func setAPIKey(_ key: String, for provider: LLMProvider) {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let account = "llm_api_key_\(provider.rawValue)"
        let service = "com.rehearsallink.api-keys"

        if trimmedKey.isEmpty {
            KeychainHelper.shared.delete(service: service, account: account)
        } else {
            KeychainHelper.shared.save(trimmedKey, service: service, account: account)
        }

        // UserDefaultsに存在する場合は削除（セキュリティ向上のため）
        UserDefaults.standard.removeObject(forKey: account)

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

    func getSystemPrompt(for task: LLMTask) -> String {
        let key = "llm_system_prompt_\(task.rawValue)"
        return UserDefaults.standard.string(forKey: key) ?? task.defaultSystemPrompt
    }

    func setSystemPrompt(_ prompt: String, for task: LLMTask) {
        let key = "llm_system_prompt_\(task.rawValue)"
        UserDefaults.standard.set(prompt, forKey: key)
        objectWillChange.send()
    }

    func resetSystemPrompt(for task: LLMTask) {
        let key = "llm_system_prompt_\(task.rawValue)"
        UserDefaults.standard.removeObject(forKey: key)
        objectWillChange.send()
    }
}
