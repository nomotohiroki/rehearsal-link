import AVFoundation
import Foundation
import Speech

actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case notAvailable
        case unsupportedLocale
        case transcriptionFailed(Error)
        case audioExportFailed
    }

    func transcribe(audioURL: URL, startTime: TimeInterval, endTime: TimeInterval, locale: Locale = .current) async throws -> String {
        // Create a temporary file for the segment to avoid SpeechAnalyzer overhead on large files
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

        // Use SpeechAnalyzer on the small temporary file
        let audioFile = try AVAudioFile(forReading: tempFileURL)
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])

        // Start analysis in a separate task
        let analysisTask = Task {
            try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
        }

        var transcript = ""

        do {
            for try await result in transcriber.results {
                transcript += String(result.text.characters)
            }
            // Wait for analysis to finish
            try await analysisTask.value
        } catch {
            analysisTask.cancel()
            throw error
        }

        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
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
