import Foundation

extension MainViewModel {
    /// 指定されたセグメントのテキストをAIで正規化（誤字修正）します
    func normalizeSegmentWithAI(id: UUID) {
        guard let index = segments.firstIndex(where: { $0.id == id }) else { return }
        let segment = segments[index]

        guard let originalText = segment.transcription, !originalText.isEmpty else {
            errorMessage = "修正するテキストがありません。"
            return
        }

        Task {
            print("MainViewModel: Starting AI normalization for segment \(id)")
            do {
                await MainActor.run { self.isTranscribing = true }

                let processor = LLMTextProcessor()
                let result = try await processor.process(originalText, task: .normalize)

                await MainActor.run {
                    self.segments[index].transcription = result
                    self.isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "AI修正に失敗しました: \(error.localizedDescription)"
                    self.isTranscribing = false
                }
            }
        }
    }

    /// リハーサル全体の要約を生成します
    func summarizeRehearsalWithAI() {
        // 文字起こしが存在する全セグメント（会話・演奏）を結合（タイムスタンプ付き）
        let targetSegments = segments.filter { ($0.type == .conversation || $0.type == .performance) && $0.transcription != nil }

        guard !targetSegments.isEmpty else {
            errorMessage = "要約するための文字起こしテキストが見つかりません。先に文字起こしを実行してください。"
            return
        }

        // テキストの構築
        var fullText = "リハーサル文字起こしデータ:\n\n"
        for segment in targetSegments {
            let timeStr = formatShortTime(segment.startTime)
            fullText += "[\(timeStr)] \(segment.transcription ?? "")\n"
        }

        Task {
            print("MainViewModel: Starting Global Rehearsal Summarization")
            do {
                await MainActor.run { self.isTranscribing = true }

                let processor = LLMTextProcessor()
                let result = try await processor.process(fullText, task: .summarize)

                await MainActor.run {
                    self.projectSummary = result
                    self.isTranscribing = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = "全体要約の生成に失敗しました: \(error.localizedDescription)"
                    self.isTranscribing = false
                }
            }
        }
    }
}
