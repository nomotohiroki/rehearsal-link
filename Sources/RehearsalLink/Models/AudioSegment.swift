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
    var isExcludedFromExport: Bool = false

    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, type, label, transcription, isExcludedFromExport
    }

    init(
        id: UUID = UUID(),
        startTime: TimeInterval,
        endTime: TimeInterval,
        type: SegmentType,
        label: String? = nil,
        transcription: String? = nil,
        isExcludedFromExport: Bool = false
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.type = type
        self.label = label
        self.transcription = transcription
        self.isExcludedFromExport = isExcludedFromExport
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        startTime = try container.decode(TimeInterval.self, forKey: .startTime)
        endTime = try container.decode(TimeInterval.self, forKey: .endTime)
        type = try container.decode(SegmentType.self, forKey: .type)
        label = try container.decodeIfPresent(String.self, forKey: .label)
        transcription = try container.decodeIfPresent(String.self, forKey: .transcription)
        isExcludedFromExport = try container.decodeIfPresent(Bool.self, forKey: .isExcludedFromExport) ?? false
    }

    var duration: TimeInterval {
        endTime - startTime
    }
}
