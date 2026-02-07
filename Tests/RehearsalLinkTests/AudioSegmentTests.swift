import XCTest
@testable import RehearsalLink

final class AudioSegmentTests: XCTestCase {
    func testAudioSegmentInitialization() {
        let id = UUID()
        let segment = AudioSegment(
            id: id,
            startTime: 0.0,
            endTime: 10.0,
            type: .performance,
            label: "Test Label",
            transcription: "Test Transcription"
        )
        
        XCTAssertEqual(segment.id, id)
        XCTAssertEqual(segment.startTime, 0.0)
        XCTAssertEqual(segment.endTime, 10.0)
        XCTAssertEqual(segment.type, .performance)
        XCTAssertEqual(segment.label, "Test Label")
        XCTAssertEqual(segment.transcription, "Test Transcription")
        XCTAssertEqual(segment.duration, 10.0)
    }
    
    func testSegmentDuration() {
        let segment = AudioSegment(startTime: 5.5, endTime: 12.3, type: .silence)
        XCTAssertEqual(segment.duration, 6.8, accuracy: 0.001)
    }
}
