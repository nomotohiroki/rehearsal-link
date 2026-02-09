import Foundation

/// OpenAI APIを使用したLLM服务
struct OpenAIService: LLMServiceProtocol {
    let provider: LLMProvider = .openai
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func process(request: LLMRequest) async throws -> LLMResponse {
        let url = URL(string: "https://api.openai.com/v1/chat/completions")!
        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = OpenAIRequest(
            model: request.model.id,
            messages: buildMessages(request: request),
            temperature: request.temperature,
            maxTokens: request.maxTokens
        )
        urlRequest.httpBody = try JSONEncoder().encode(body)

        let (data, response) = try await session.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LLMError.unknownError("Invalid response")
        }

        if httpResponse.statusCode != 200 {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw LLMError.apiError(status: httpResponse.statusCode, message: errorMsg)
        }

        let openAIResponse = try JSONDecoder().decode(OpenAIResponse.self, from: data)

        guard let choice = openAIResponse.choices.first else {
            throw LLMError.unknownError("No completion choices returned")
        }

        return LLMResponse(
            text: choice.message.content,
            usage: LLMUsage(
                promptTokens: openAIResponse.usage.promptTokens,
                completionTokens: openAIResponse.usage.completionTokens,
                totalTokens: openAIResponse.usage.totalTokens
            )
        )
    }

    private func buildMessages(request: LLMRequest) -> [OpenAIMessage] {
        var messages: [OpenAIMessage] = []
        if let systemPrompt = request.systemPrompt {
            messages.append(OpenAIMessage(role: "system", content: systemPrompt))
        }
        messages.append(OpenAIMessage(role: "user", content: request.prompt))
        return messages
    }
}

// MARK: - OpenAI API Models

private struct OpenAIRequest: Encodable {
    let model: String
    let messages: [OpenAIMessage]
    let temperature: Float
    let maxTokens: Int?

    enum CodingKeys: String, CodingKey {
        case model, messages, temperature
        case maxTokens = "max_tokens"
    }
}

private struct OpenAIMessage: Codable {
    let role: String
    let content: String
}

private struct OpenAIResponse: Decodable {
    let choices: [OpenAIChoice]
    let usage: OpenAIUsage
}

private struct OpenAIChoice: Decodable {
    let message: OpenAIMessage
}

private struct OpenAIUsage: Decodable {
    let promptTokens: Int
    let completionTokens: Int
    let totalTokens: Int

    enum CodingKeys: String, CodingKey {
        case promptTokens = "prompt_tokens"
        case completionTokens = "completion_tokens"
        case totalTokens = "total_tokens"
    }
}
