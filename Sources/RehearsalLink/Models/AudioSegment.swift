import Foundation

enum SegmentType: String, Codable {
    case performance
    case conversation
    case silence
}

struct AudioSegment: Identifiable, Codable {
    let id: UUID
    let startTime: TimeInterval
    let endTime: TimeInterval
    let type: SegmentType
    var label: String?
    var transcription: String?
    
    init(id: UUID = UUID(), startTime: TimeInterval, endTime: TimeInterval, type: SegmentType, label: String? = nil, transcription: String? = nil) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.label = label
        self.transcription = transcription
    }
    
    var duration: TimeInterval {
        endTime - startTime
    }
}
