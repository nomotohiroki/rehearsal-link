import Foundation

/// LLMサービスが共通で実装すべきプロトコル
protocol LLMServiceProtocol: Sendable {
    /// 処理対象のプロバイダー
    var provider: LLMProvider { get }

    /// テキスト処理を実行します（非同期・非ストリーミング）
    /// - Parameter request: 処理リクエスト
    /// - Returns: 処理結果のレスポンス
    func process(request: LLMRequest) async throws -> LLMResponse

    /// テキスト処理をストリーミングで実行します（任意実装）
    /// - Parameter request: 処理リクエスト
    /// - Returns: テキストの断片を流すAsyncThrowingStream
    func processStream(request: LLMRequest) -> AsyncThrowingStream<String, Error>
}

/// ストリーミングのデフォルト実装（未対応の場合は一括で返す）
extension LLMServiceProtocol {
    func processStream(request: LLMRequest) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            Task {
                do {
                    let response = try await process(request: request)
                    continuation.yield(response.text)
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
        }
    }
}
