import XCTest
@testable import RehearsalLink

@MainActor
final class MainViewModelTests: XCTestCase {
    var viewModel: MainViewModel!
    
    override func setUp() async throws {
        try await super.setUp()
        viewModel = MainViewModel()
    }
    
    func testInitialState() {
        XCTAssertNil(viewModel.audioData)
        XCTAssertFalse(viewModel.isLoading)
        XCTAssertTrue(viewModel.segments.isEmpty)
    }
    
    func testUpdateSegmentType() {
        let id = UUID()
        let segment = AudioSegment(id: id, startTime: 0, endTime: 10, type: .silence)
        viewModel.segments = [segment]
        
        viewModel.updateSegmentType(id: id, type: .performance)
        
        XCTAssertEqual(viewModel.segments[0].type, .performance)
    }
    
    func testUpdateSegmentLabel() {
        let id = UUID()
        let segment = AudioSegment(id: id, startTime: 0, endTime: 10, type: .performance)
        viewModel.segments = [segment]
        
        viewModel.updateSegmentLabel(id: id, label: "New Label")
        
        XCTAssertEqual(viewModel.segments[0].label, "New Label")
    }
    
    func testSplitSegment() {
        let segment = AudioSegment(startTime: 0, endTime: 10, type: .performance)
        viewModel.segments = [segment]
        
        viewModel.splitSegment(at: 5.0)
        
        XCTAssertEqual(viewModel.segments.count, 2)
        XCTAssertEqual(viewModel.segments[0].startTime, 0)
        XCTAssertEqual(viewModel.segments[0].endTime, 5.0)
        XCTAssertEqual(viewModel.segments[1].startTime, 5.0)
        XCTAssertEqual(viewModel.segments[1].endTime, 10.0)
    }
    
    func testMergeWithNext() {
        let id1 = UUID()
        let segment1 = AudioSegment(id: id1, startTime: 0, endTime: 5, type: .performance, transcription: "Part 1")
        let segment2 = AudioSegment(startTime: 5, endTime: 10, type: .performance, transcription: "Part 2")
        viewModel.segments = [segment1, segment2]
        
        viewModel.mergeWithNext(id: id1)
        
        XCTAssertEqual(viewModel.segments.count, 1)
        XCTAssertEqual(viewModel.segments[0].startTime, 0)
        XCTAssertEqual(viewModel.segments[0].endTime, 10.0)
        XCTAssertEqual(viewModel.segments[0].transcription, "Part 1\nPart 2")
    }
}
