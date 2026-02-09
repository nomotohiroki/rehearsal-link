import Foundation

/// Google Gemini API を使用した LLM サービス
struct GeminiService: LLMServiceProtocol {
    let provider: LLMProvider = .gemini
    private let apiKey: String
    private let session: URLSession

    init(apiKey: String, session: URLSession = .shared) {
        self.apiKey = apiKey
        self.session = session
    }

    func process(request: LLMRequest) async throws -> LLMResponse {
        let urlString = "https://generativelanguage.googleapis.com/v1beta/models/\(request.model.id):generateContent?key=\(apiKey)"
        guard let url = URL(string: urlString) else {
            throw LLMError.unknownError("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body = GeminiRequest(
            contents: [
                GeminiContent(role: "user", parts: [GeminiPart(text: request.prompt)])
            ],
            systemInstruction: request.systemPrompt != nil ? GeminiContent(parts: [GeminiPart(text: request.systemPrompt!)]) : nil,
            generationConfig: GeminiConfig(
                temperature: request.temperature,
                maxOutputTokens: request.maxTokens
            )
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

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: data)

        guard let text = geminiResponse.candidates.first?.content.parts.first?.text else {
            throw LLMError.unknownError("No content returned from Gemini")
        }

        let usage = geminiResponse.usageMetadata.map { metadata in
            LLMUsage(
                promptTokens: metadata.promptTokenCount,
                completionTokens: metadata.candidatesTokenCount,
                totalTokens: metadata.totalTokenCount
            )
        }

        return LLMResponse(
            text: text,
            usage: usage
        )
    }
}

// MARK: - Gemini API Models

private struct GeminiRequest: Encodable {
    let contents: [GeminiContent]
    let systemInstruction: GeminiContent?
    let generationConfig: GeminiConfig?
}

private struct GeminiContent: Codable {
    var role: String?
    let parts: [GeminiPart]
}

private struct GeminiPart: Codable {
    let text: String
}

private struct GeminiConfig: Encodable {
    let temperature: Float?
    let maxOutputTokens: Int?
}

private struct GeminiResponse: Decodable {
    let candidates: [GeminiCandidate]
    let usageMetadata: GeminiUsageMetadata?
}

private struct GeminiCandidate: Decodable {
    let content: GeminiContent
}

private struct GeminiUsageMetadata: Decodable {
    let promptTokenCount: Int
    let candidatesTokenCount: Int
    let totalTokenCount: Int
}
