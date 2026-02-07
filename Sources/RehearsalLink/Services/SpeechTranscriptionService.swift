import Foundation
import Speech
import AVFoundation

actor SpeechTranscriptionService {
    enum TranscriptionError: Error {
        case notAvailable
        case unsupportedLocale
        case transcriptionFailed(Error)
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

        // Use SpeechAnalyzer (macOS 15/26+)
        let audioFile = try AVAudioFile(forReading: audioURL)
        let sampleRate = audioFile.processingFormat.sampleRate
        
        // Seek to start time
        let startFrame = AVAudioFramePosition(startTime * sampleRate)
        audioFile.framePosition = startFrame
        
        let transcriber = SpeechTranscriber(locale: locale, preset: .transcription)
        let analyzer = SpeechAnalyzer(modules: [transcriber])
        
        // Start analysis
        // Since we want to limit it to a segment, and SpeechAnalyzer reads until the end of the file,
        // we will process the results and stop when we reach the segment end time.
        try await analyzer.start(inputAudioFile: audioFile, finishAfterFile: true)
        
        var transcript = ""
        let duration = endTime - startTime
        
        for try await result in transcriber.results {
            // Append the text
            transcript += String(result.text.characters)
            
            // Check if we've reached the end of our desired segment
            if result.resultsFinalizationTime.seconds >= duration {
                break
            }
        }
        
        return transcript.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
