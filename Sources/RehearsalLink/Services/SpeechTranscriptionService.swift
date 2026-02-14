import AVFoundation
import Foundation
import Speech

actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case notAvailable
        case internalError(String)
        case transcriptionFailed(Error)
    }

    // SFSpeechRecognizerは比較的重いオブジェクトなので、再利用する
    private let speechRecognizer: SFSpeechRecognizer

    init() throws {
        guard let recognizer = SFSpeechRecognizer(locale: .current) else {
            throw TranscriptionError.notAvailable
        }
        self.speechRecognizer = recognizer
    }

    func transcribe(audioFile: AVAudioFile, startTime: TimeInterval, endTime: TimeInterval) async throws -> String {
        guard speechRecognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }
        
        // 1. 指定された範囲のオーディオデータを読み込む
        let originalFormat = audioFile.processingFormat
        let sampleRate = originalFormat.sampleRate
        
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        let endFrame = AVAudioFramePosition(endTime * sampleRate)
        guard endFrame > startFrame else { return "" }
        
        let frameCount = AVAudioFrameCount(endFrame - startFrame)
        
        guard let buffer = AVAudioPCMBuffer(pcmFormat: originalFormat, frameCapacity: frameCount) else {
            throw TranscriptionError.internalError("Failed to create PCM buffer.")
        }
        
        do {
            audioFile.framePosition = startFrame
            try audioFile.read(into: buffer)
        } catch {
            throw TranscriptionError.internalError("Failed to read audio file segment: \(error.localizedDescription)")
        }

        // 2. 認識リクエストを作成してバッファを渡す
        return try await withCheckedThrowingContinuation { continuation in
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.append(buffer)
            request.endAudio()

            _ = speechRecognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error))
                    return
                }
                
                guard let result = result else {
                    // 通常、エラーか結果のどちらかは存在する
                    continuation.resume(throwing: TranscriptionError.internalError("Recognition produced no result or error."))
                    return
                }

                if result.isFinal {
                    let transcript = result.bestTranscription.formattedString
                    continuation.resume(returning: transcript.trimmingCharacters(in: .whitespacesAndNewlines))
                }
            }
        }
    }
}
