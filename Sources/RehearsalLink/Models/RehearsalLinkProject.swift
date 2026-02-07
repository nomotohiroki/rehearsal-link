import Foundation

struct RehearsalLinkProject: Codable {
    let audioFileURL: URL
    let segments: [AudioSegment]
    let createdAt: Date
    let modifiedAt: Date
    
    init(audioFileURL: URL, segments: [AudioSegment]) {
        self.audioFileURL = audioFileURL
        self.segments = segments
        self.createdAt = Date()
        self.modifiedAt = Date()
    }
}