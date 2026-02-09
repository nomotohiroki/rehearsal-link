import Foundation

/// Anthropic API (Claude) を使用した LLM サービス
struct AnthropicService: LLMServiceProtocol {
    let provider: LLMProvider = .anthropic
    private let apiKey: String
    private let session: URLSession
    private let anthropicVersion = "2023-06-01"

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func process(request: LLMRequest) async throws -> LLMResponse {
        let url = URL(string: "https://api.anthropic.com/v1/messages")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        urlRequest.setValue(anthropicVersion, forHTTPHeaderField: "anthropic-version")
        urlRequest.setValue("application/json", forHTTPHeaderField: "content-type")

        let body = AnthropicRequest(
            model: request.model.id,
            messages: [AnthropicMessage(role: "user", content: request.prompt)],
            system: request.systemPrompt,
            maxTokens: request.maxTokens ?? 4096,
            temperature: request.temperature
        )
        let jsonData = try JSONEncoder().encode(body)
        urlRequest.httpBody = jsonData

        print("--- Anthropic Request ---")
        print("URL: \(url)")
        print("Model: \(request.model.id)")
        print("System Prompt: \(request.systemPrompt ?? "none")")
        print("User Prompt: \(request.prompt)")
        if let bodyString = String(data: jsonData, encoding: .utf8) {
            print("Body: \(bodyString)")
        }

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            print("Anthropic Error: Invalid response type")
            throw LLMError.unknownError("Invalid response")
        }

        print("--- Anthropic Response (\(httpResponse.statusCode)) ---")
        if let responseString = String(data: data, encoding: .utf8) {
            print("Data: \(responseString)")
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(status: httpResponse.statusCode, message: errorMsg)
        }

        let anthropicResponse = try JSONDecoder().decode(AnthropicResponse.self, from: data)

        let text = anthropicResponse.content.first?.text ?? ""

        return LLMResponse(
            text: text,
            usage: LLMUsage(
                promptTokens: anthropicResponse.usage.inputTokens,
                completionTokens: anthropicResponse.usage.outputTokens,
                totalTokens: anthropicResponse.usage.inputTokens + anthropicResponse.usage.outputTokens
            )
        )
    }
}

// MARK: - Anthropic API Models

private struct AnthropicRequest: Encodable {
    let model: String
    let messages: [AnthropicMessage]
    let system: String?
    let maxTokens: Int
    let temperature: Float

    enum CodingKeys: String, CodingKey {
        case model, messages, system, temperature
        case maxTokens = "max_tokens"
    }
}

private struct AnthropicMessage: Codable {
    let role: String
    let content: String
}

private struct AnthropicResponse: Decodable {
    let content: [AnthropicContentBlock]
    let usage: AnthropicUsage
}

private struct AnthropicContentBlock: Decodable {
    let text: String
}

private struct AnthropicUsage: Decodable {
    let inputTokens: Int
    let outputTokens: Int

    enum CodingKeys: String, CodingKey {
        case inputTokens = "input_tokens"
        case outputTokens = "output_tokens"
    }
}
