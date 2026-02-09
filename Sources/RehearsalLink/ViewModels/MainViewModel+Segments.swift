import Foundation

extension MainViewModel {
    func updateSegmentType(id: UUID, type: SegmentType) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: type,
                label: oldSegment.label,
                transcription: oldSegment.transcription,
                isExcludedFromExport: oldSegment.isExcludedFromExport
            )
        }
    }

    func updateSegmentLabel(id: UUID, label: String) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: oldSegment.type,
                label: label.isEmpty ? nil : label,
                transcription: oldSegment.transcription,
                isExcludedFromExport: oldSegment.isExcludedFromExport
            )
        }
    }

    func updateTranscription(id: UUID, text: String) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: oldSegment.type,
                label: oldSegment.label,
                transcription: text,
                isExcludedFromExport: oldSegment.isExcludedFromExport
            )
        }
    }

    func updateSegmentExportExclusion(id: UUID, isExcluded: Bool) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: oldSegment.type,
                label: oldSegment.label,
                transcription: oldSegment.transcription,
                isExcludedFromExport: isExcluded
            )
        }
    }

    func moveBoundary(index: Int, newTime: TimeInterval) {
        guard index >= 0, index < segments.count - 1 else { return }

        let minTime = index > 0 ? segments[index - 1].endTime + 0.1 : 0.1
        let maxTime = segments[index + 1].endTime - 0.1

        let clampedTime = max(minTime, min(newTime, maxTime))

        let left = segments[index]
        let right = segments[index + 1]

        segments[index] = AudioSegment(
            id: left.id,
            startTime: left.startTime,
            endTime: clampedTime,
            type: left.type,
            label: left.label,
            transcription: left.transcription,
            isExcludedFromExport: left.isExcludedFromExport
        )
        segments[index + 1] = AudioSegment(
            id: right.id,
            startTime: clampedTime,
            endTime: right.endTime,
            type: right.type,
            label: right.label,
            transcription: right.transcription,
            isExcludedFromExport: right.isExcludedFromExport
        )
    }

    func splitSegment(at time: TimeInterval) {
        guard let index = segments.firstIndex(where: { time > $0.startTime && time < $0.endTime }) else {
            return
        }

        let segment = segments[index]
        // 極端に短いセグメントができないようにチェック
        guard time - segment.startTime > 0.1, segment.endTime - time > 0.1 else {
            return
        }

        let left = AudioSegment(startTime: segment.startTime, endTime: time, type: segment.type, isExcludedFromExport: segment.isExcludedFromExport)
        let right = AudioSegment(startTime: time, endTime: segment.endTime, type: segment.type, isExcludedFromExport: segment.isExcludedFromExport)

        segments.remove(at: index)
        segments.insert(right, at: index)
        segments.insert(left, at: index)
    }

    func mergeWithNext(id: UUID) {
        guard let index = segments.firstIndex(where: { $0.id == id }),
              index < segments.count - 1 else { return }

        let current = segments[index]
        let next = segments[index + 1]

        // 文字起こしテキストの結合
        let mergedTranscription: String?
        if let t1 = current.transcription, let t2 = next.transcription {
            mergedTranscription = t1 + "\n" + t2
        } else {
            mergedTranscription = current.transcription ?? next.transcription
        }

        // ラベルの継承（左優先）
        let mergedLabel: String? = current.label ?? next.label

        let mergedSegment = AudioSegment(
            id: current.id, // IDを保持
            startTime: current.startTime,
            endTime: next.endTime,
            type: current.type, // 左側のタイプを優先
            label: mergedLabel,
            transcription: mergedTranscription,
            isExcludedFromExport: current.isExcludedFromExport // 左側の設定を優先
        )

        segments.remove(at: index + 1)
        segments[index] = mergedSegment

        // 結合後のセグメントを選択
        selectedSegmentId = mergedSegment.id
    }
}
