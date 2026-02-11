import Foundation

/// 文字起こしテキストに対してAI処理（正規化・要約）を行うサービス
@MainActor
struct LLMTextProcessor {
    private let config = LLMConfigurationService.shared

    /// 指定されたタスクでテキストを処理します
    func process(_ text: String, task: LLMTask) async throws -> String {
        guard let service = config.makeService() else {
            throw LLMError.invalidAPIKey
        }

        let model = config.getSelectedModel()
        let request = LLMRequest(
            prompt: text,
            systemPrompt: config.getSystemPrompt(for: task),
            model: model,
            temperature: task == .summarize ? 0.3 : 0.1 // 要約は少し柔軟に、正規化は忠実に
        )

        let response = try await service.process(request: request)
        return response.text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
