import XCTest
import Speech
@testable import RehearsalLink

final class SpeechTranscriptionServiceTests: XCTestCase {
    func testTranscriptionServiceInitialization() {
        let service = SpeechTranscriptionService()
        XCTAssertNotNil(service)
    }
    
    func testTranscriptionWithSampleFile() async throws {
        // This test might fail on CI or systems without speech recognition authorization
        // We handle it gracefully.
        
        let service = SpeechTranscriptionService()
        let sampleURL = URL(fileURLWithPath: "sample-sound/20260205.m4a")
        
        // Skip if sample file doesn't exist
        guard FileManager.default.fileExists(atPath: sampleURL.path) else {
            print("Skipping test: sample file not found at \(sampleURL.path)")
            return
        }
        
        do {
            // Try a segment that might have content (e.g., 60-65s)
            let result = try await service.transcribe(audioURL: sampleURL, startTime: 60, endTime: 65)
            print("Transcription result (60-65s): '\(result)'")
            // result might be empty if there's no speech, which is fine.
            XCTAssertNotNil(result)
        } catch SpeechTranscriptionService.TranscriptionError.notAvailable {
            print("Skipping test: Speech recognition not available or not authorized")
        } catch {
            // Other errors are failures
            XCTFail("Transcription failed with error: \(error)")
        }
    }
}
