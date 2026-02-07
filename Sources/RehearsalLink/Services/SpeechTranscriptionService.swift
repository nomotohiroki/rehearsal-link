import Foundation
import Speech
@preconcurrency import AVFoundation

actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case notAvailable
        case unsupportedLocale
        case transcriptionFailed(Error?)
        case audioExportFailed
    }
    
    func transcribe(audioURL: URL, startTime: TimeInterval, endTime: TimeInterval, locale: Locale = .current) async throws -> String {
        // Check authorization
        let status = SFSpeechRecognizer.authorizationStatus()
        if status == .notDetermined {
            await withCheckedContinuation { continuation in
                SFSpeechRecognizer.requestAuthorization { _ in
                    continuation.resume()
                }
            }
        }
        
        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            throw TranscriptionError.notAvailable
        }

        // Create a temporary file for the segment
        let tempDir = FileManager.default.temporaryDirectory
        let tempFileURL = tempDir.appendingPathComponent(UUID().uuidString + ".m4a")
        
        do {
            try await extractSegment(from: audioURL, startTime: startTime, endTime: endTime, outputURL: tempFileURL)
        } catch {
            print("Failed to extract segment: \(error)")
            throw TranscriptionError.audioExportFailed
        }
        
        defer {
            try? FileManager.default.removeItem(at: tempFileURL)
        }

        // Use SFSpeechRecognizer
        guard let recognizer = SFSpeechRecognizer(locale: locale), recognizer.isAvailable else {
            throw TranscriptionError.notAvailable
        }
        
        let request = SFSpeechURLRecognitionRequest(url: tempFileURL)
        request.shouldReportPartialResults = false
        
        return try await withCheckedThrowingContinuation { continuation in
            recognizer.recognitionTask(with: request) { result, error in
                if let error = error {
                    continuation.resume(throwing: TranscriptionError.transcriptionFailed(error))
                    return
                }
                
                if let result = result, result.isFinal {
                    continuation.resume(returning: result.bestTranscription.formattedString)
                }
            }
        }
    }
    
    /// Extracts a segment of audio into a new temporary M4A file
    private func extractSegment(from inputURL: URL, startTime: TimeInterval, endTime: TimeInterval, outputURL: URL) async throws {
        let asset = AVURLAsset(url: inputURL)
        
        guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
            throw TranscriptionError.audioExportFailed
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        
        let range = CMTimeRange(
            start: CMTime(seconds: startTime, preferredTimescale: 600),
            duration: CMTime(seconds: endTime - startTime, preferredTimescale: 600)
        )
        exportSession.timeRange = range
        
        // Use the new async export method for macOS 15+
        try await exportSession.export(to: outputURL, as: .m4a)
    }
}
