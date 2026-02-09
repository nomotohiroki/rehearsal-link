import Foundation

struct RehearsalLinkProject: Codable {
    let audioFileURL: URL
    let segments: [AudioSegment]
    var summary: String? // プロジェクト全体の要約
    let createdAt: Date
    var modifiedAt: Date

    init(audioFileURL: URL, segments: [AudioSegment], summary: String? = nil) {
        self.audioFileURL = audioFileURL
        self.segments = segments
        self.summary = summary
        createdAt = Date()
        modifiedAt = Date()
    }
}
