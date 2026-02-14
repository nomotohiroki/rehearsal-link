import AppKit
import Foundation

extension MainViewModel {
    func transcribeSegment(id: UUID) {
        guard let index = segments.firstIndex(where: { $0.id == id }),
              let audioData = audioData else { return }

        let segment = segments[index]
        guard segment.type == .conversation || segment.type == .performance else { return }

        isTranscribing = true
        errorMessage = nil

        Task {
            do {
                guard let service = transcriptionService else {
                    throw URLError(.unknown) // Or a more specific error
                }
                
                let text = try await service.transcribe(
                    audioFile: audioData.audioFile,
                    startTime: segment.startTime,
                    endTime: segment.endTime
                )

                await MainActor.run {
                    if let currentIndex = self.segments.firstIndex(where: { $0.id == id }) {
                        let oldSegment = self.segments[currentIndex]
                        self.segments[currentIndex] = AudioSegment(
                            id: oldSegment.id,
                            startTime: oldSegment.startTime,
                            endTime: oldSegment.endTime,
                            type: oldSegment.type,
                            label: oldSegment.label,
                            transcription: text,
                            isExcludedFromExport: oldSegment.isExcludedFromExport
                        )
                    }
                    self.isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "文字起こしに失敗しました: \(error.localizedDescription)"
                    self.isTranscribing = false
                }
            }
        }
    }

    func batchTranscribe() {
        guard let audioData = audioData, let service = transcriptionService else { return }

        let targetSegments = segments.filter { ($0.type == .conversation || $0.type == .performance) && $0.transcription == nil }
        guard !targetSegments.isEmpty else { return }

        isBatchTranscribing = true
        batchTranscriptionProgress = 0
        errorMessage = nil

        Task {
            var completedCount = 0
            let totalCount = targetSegments.count

            for segment in targetSegments {
                // 連続実行による負荷を軽減するため、各処理の間にわずかな空きを作る
                await Task.yield()

                do {
                    let text = try await service.transcribe(
                        audioFile: audioData.audioFile,
                        startTime: segment.startTime,
                        endTime: segment.endTime
                    )

                    await MainActor.run {
                        if let index = self.segments.firstIndex(where: { $0.id == segment.id }) {
                            let oldSegment = self.segments[index]
                            self.segments[index] = AudioSegment(
                                id: oldSegment.id,
                                startTime: oldSegment.startTime,
                                endTime: oldSegment.endTime,
                                type: oldSegment.type,
                                label: oldSegment.label,
                                transcription: text,
                                isExcludedFromExport: oldSegment.isExcludedFromExport
                            )
                        }
                        completedCount += 1
                        self.batchTranscriptionProgress = Double(completedCount) / Double(totalCount)
                    }
                } catch {
                    print("Batch transcription error for segment \(segment.id): \(error)")
                    // 個別のエラーはログに記録し、続行する
                }
            }

            await MainActor.run {
                self.isBatchTranscribing = false
                self.batchTranscriptionProgress = 1.0
            }
        }
    }

    func exportAllTranscriptions() {
        guard let audioData = audioData else { return }

        let transcribedSegments = segments.filter { $0.transcription != nil }
        guard !transcribedSegments.isEmpty else {
            errorMessage = "文字起こし済みのセグメントがありません。"
            return
        }

        // テキストの組み立て
        var fullText = "Project: \(audioData.fileName)\n"
        fullText += "Generated: \(Date().formatted())\n\n"

        for segment in transcribedSegments {
            let timestamp = formatTime(segment.startTime)
            let label = segment.label ?? "Segment"
            fullText += "[\(timestamp)] \(label):\n"
            fullText += "\(segment.transcription ?? "")\n\n"
        }

        Task {
            let savePanel = NSSavePanel()
            savePanel.allowedContentTypes = [.plainText]
            savePanel.nameFieldStringValue = audioData.fileName.replacingOccurrences(of: "." + audioData.url.pathExtension, with: "") + "_transcription.txt"

            let response = await savePanel.begin()
            guard response == .OK, let outputURL = savePanel.url else { return }

            do {
                try fullText.write(to: outputURL, atomically: true, encoding: .utf8)
            } catch {
                self.errorMessage = "ファイルの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
