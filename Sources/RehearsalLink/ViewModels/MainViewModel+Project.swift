import AppKit
import Foundation

extension MainViewModel {
    func saveProject() {
        guard let audioData = audioData else { return }
        Task {
            do {
                try await projectService.saveProject(
                    audioFileURL: audioData.url,
                    segments: segments,
                    summary: projectSummary
                )
            } catch ProjectService.ProjectError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "プロジェクトの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }

    func loadProject() {
        Task {
            do {
                let project = try await projectService.loadProject()
                try await performLoadProject(project)
            } catch ProjectService.ProjectError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "プロジェクトの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
        }
    }

    func exportSegments(type: SegmentType) {
        guard let audioData = audioData else { return }

        let targetSegments = segments.filter { $0.type == type }
        guard !targetSegments.isEmpty else {
            errorMessage = "書き出すセグメントが見つかりません。"
            return
        }

        Task {
            isLoading = true
            errorMessage = nil
            do {
                let savePanel = NSSavePanel()
                savePanel.allowedContentTypes = [.mpeg4Audio]
                let suffix = type == .performance ? "_music" : "_speech"
                savePanel.nameFieldStringValue = audioData.fileName.replacingOccurrences(of: "." + audioData.url.pathExtension, with: "") + suffix + ".m4a"

                let response = await savePanel.begin()
                guard response == .OK, let outputURL = savePanel.url else {
                    isLoading = false
                    return
                }

                try await exportService.exportSegments(
                    audioURL: audioData.url,
                    segments: targetSegments,
                    outputURL: outputURL,
                    isConversation: type == .conversation
                )
                print("Export successful: \(outputURL.path)")
            } catch {
                self.errorMessage = "書き出しに失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
        }
    }

    func performLoadProject(_ project: RehearsalLinkProject) async throws {
        isLoading = true
        errorMessage = nil

        // オーディオファイルの読み込み
        let data = try await audioLoadService.loadAudio(from: project.audioFileURL)
        audioData = data
        isLoading = false
        isAnalyzing = true

        // セグメント情報と要約をプロジェクトから取得
        segments = project.segments
        projectSummary = project.summary

        // プレイヤーにロード
        try audioPlayerService.load(data: data)

        // 波形のみバックグラウンドで解析
        let analyzer = waveformAnalyzer
        let result: Result<[WaveformSample], Error> = await Task.detached(priority: .userInitiated) {
            do {
                let samples = try analyzer.generateWaveformSamples(from: data.audioFile, targetSampleCount: 1000)
                return .success(samples)
            } catch {
                return .failure(error)
            }
        }.value

        switch result {
        case .success(let samples):
            self.waveformSamples = samples
        case .failure(let error):
            self.errorMessage = "波形データの生成に失敗しました: \(error.localizedDescription)"
        }
        
        isAnalyzing = false
    }
}
