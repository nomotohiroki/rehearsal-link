import XCTest
@testable import RehearsalLink

@MainActor
final class ProjectServiceTests: XCTestCase {
    var service: ProjectService!
    
    override func setUp() async throws {
        try await super.setUp()
        service = ProjectService()
    }
    
    func testLoadProjectFromData() async throws {
        let json = """
        {
          "audioFileURL": "file:///tmp/test.m4a",
          "segments": [
            {
              "id": "550e8400-e29b-41d4-a716-446655440000",
              "startTime": 0,
              "endTime": 10,
              "type": "performance",
              "label": "Test"
            }
          ],
          "createdAt": 760000000.0,
          "modifiedAt": 760000000.0
        }
        """.data(using: .utf8)!
        
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("test.rehearsallink")
        try json.write(to: tempURL)
        defer { try? FileManager.default.removeItem(at: tempURL) }
        
        let project = try await service.loadProject(from: tempURL)
        
        XCTAssertEqual(project.audioFileURL.lastPathComponent, "test.m4a")
        XCTAssertEqual(project.segments.count, 1)
        XCTAssertEqual(project.segments[0].type, .performance)
        XCTAssertEqual(project.segments[0].label, "Test")
    }
}
