import Combine
import Foundation
import SwiftUI

@MainActor
class MainViewModel: ObservableObject {
    @Published var audioData: AudioData?
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var waveformSamples: [WaveformSample] = []
    @Published var audioFeatures: [AudioFeaturePoint] = []
    @Published var segments: [AudioSegment] = []
    @Published var selectedSegmentId: UUID?

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var isLoopingEnabled = false
    @Published var isTranscribing = false
    @Published var isBatchTranscribing = false
    @Published var batchTranscriptionProgress: Double = 0

    @Published var zoomLevel: Double = 1.0 // 1.0 = fit to width

    @Published var showProjectDetectedAlert = false
    private var pendingAudioURL: URL?
    private var pendingProjectURL: URL?

    let audioLoadService = AudioLoadService()
    let waveformAnalyzer = WaveformAnalyzer()
    let audioProcessor = AudioProcessor()
    let audioPlayerService = AudioPlayerService()
    let projectService = ProjectService()
    let exportService = ExportService()
    let transcriptionService = SpeechTranscriptionService()

    var cancellables = Set<AnyCancellable>()

    init() {
        // AudioPlayerServiceの状態を購読
        audioPlayerService.$isPlaying
            .receive(on: RunLoop.main)
            .assign(to: &$isPlaying)

        audioPlayerService.$currentTime
            .receive(on: RunLoop.main)
            .assign(to: &$currentTime)

        // ループ設定の同期
        $isLoopingEnabled
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                self?.audioPlayerService.isLooping = enabled
                self?.updateLoopRange()
            }
            .store(in: &cancellables)

        $selectedSegmentId
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLoopRange()
            }
            .store(in: &cancellables)

        $segments
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateLoopRange()
            }
            .store(in: &cancellables)
    }

    private func updateLoopRange() {
        if isLoopingEnabled, let selectedId = selectedSegmentId,
           let segment = segments.first(where: { $0.id == selectedId }) {
            audioPlayerService.loopRange = segment.startTime ... segment.endTime
        } else {
            audioPlayerService.loopRange = nil
        }
    }

    func selectFile() {
        Task {
            do {
                let audioURL = try await audioLoadService.selectAudioFile()
                handleFile(at: audioURL)
            } catch AudioLoadService.AudioLoadError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
        }
    }

    func handleFile(at url: URL) {
        Task {
            do {
                // プロジェクトファイルの候補を複数チェック
                let baseURL = url.deletingPathExtension()
                let projectURL = baseURL.appendingPathExtension("rehearsallink")
                let projectJSONURL = baseURL.appendingPathExtension("rehearsallink").appendingPathExtension("json")

                if FileManager.default.fileExists(atPath: projectURL.path) {
                    self.pendingAudioURL = url
                    self.pendingProjectURL = projectURL
                    self.showProjectDetectedAlert = true
                } else if FileManager.default.fileExists(atPath: projectJSONURL.path) {
                    self.pendingAudioURL = url
                    self.pendingProjectURL = projectJSONURL
                    self.showProjectDetectedAlert = true
                } else {
                    try await performLoadAudio(from: url)
                }
            } catch {
                self.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
        }
    }

    private func performLoadAudio(from url: URL) async throws {
        isLoading = true
        errorMessage = nil

        print("MainViewModel: Starting load...")
        let data = try await audioLoadService.loadAudio(from: url)
        audioData = data
        isLoading = false
        isAnalyzing = true
        print("MainViewModel: AudioData set. Duration: \(data.duration)")

        // プレイヤーにロード
        audioPlayerService.load(url: data.url)

        // 重い解析処理をバックグラウンドで行う
        let analyzer = waveformAnalyzer
        let (samples, features, segments) = await Task.detached(priority: .userInitiated) {
            let samples = analyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
            let features = analyzer.extractFeatures(from: data.pcmBuffer)
            let segments = analyzer.calculateSegments(from: features)
            return (samples, features, segments)
        }.value

        waveformSamples = samples
        audioFeatures = features
        self.segments = segments
        isAnalyzing = false

        print("MainViewModel: Analysis complete.")
    }

    func performLoadProject(_ project: RehearsalLinkProject) async throws {
        isLoading = true
        errorMessage = nil

        // オーディオファイルの読み込み
        let data = try await audioLoadService.loadAudio(from: project.audioFileURL)
        audioData = data
        isLoading = false
        isAnalyzing = true

        // セグメント情報はプロジェクトから取得（解析を待たずに表示可能）
        segments = project.segments

        // プレイヤーにロード
        audioPlayerService.load(url: data.url)

        // 波形のみバックグラウンドで解析
        let analyzer = waveformAnalyzer
        let samples = await Task.detached(priority: .userInitiated) {
            analyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
        }.value

        waveformSamples = samples
        isAnalyzing = false
    }

    func loadDetectedProject() {
        guard let projectURL = pendingProjectURL else { return }
        Task {
            do {
                let project = try await projectService.loadProject(from: projectURL)
                try await performLoadProject(project)
            } catch {
                self.errorMessage = "プロジェクトの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
            pendingAudioURL = nil
            pendingProjectURL = nil
        }
    }

    func loadAudioOnly() {
        guard let audioURL = pendingAudioURL else { return }
        Task {
            do {
                try await performLoadAudio(from: audioURL)
            } catch {
                self.errorMessage = "オーディオの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
            pendingAudioURL = nil
            pendingProjectURL = nil
        }
    }

    func togglePlayback() {
        if isPlaying {
            audioPlayerService.pause()
        } else {
            audioPlayerService.play()
        }
    }

    func stopPlayback() {
        audioPlayerService.stop()
    }

    func seek(to time: TimeInterval) {
        audioPlayerService.seek(to: time)
    }

    func seek(progress: Double) {
        guard let data = audioData else { return }
        seek(to: data.duration * progress)
    }

    // MARK: - Zoom Actions

    func zoomIn() {
        zoomLevel = min(zoomLevel * 1.5, 50.0)
    }

    func zoomOut() {
        zoomLevel = max(zoomLevel / 1.5, 1.0)
    }

    func resetZoom() {
        zoomLevel = 1.0
    }

    func normalizeAndReanalyze() {
        guard let data = audioData else { return }

        isLoading = true
        isAnalyzing = true
        errorMessage = nil

        Task {
            // より強力なRMS正規化（目標 -20dBFS）を適用
            guard let normalizedBuffer = audioProcessor.normalizeRMS(buffer: data.pcmBuffer, targetRMSDecibels: -20.0) else {
                await MainActor.run {
                    self.errorMessage = "正規化処理に失敗しました。"
                    self.isLoading = false
                    self.isAnalyzing = false
                }
                return
            }

            // AudioDataを更新
            let newData = AudioData(
                url: data.url,
                pcmBuffer: normalizedBuffer
            )

            await MainActor.run {
                self.audioData = newData
            }

            // 再解析
            let analyzer = waveformAnalyzer
            let (samples, features, segments) = await Task.detached(priority: .userInitiated) {
                let samples = analyzer.generateWaveformSamples(from: normalizedBuffer, targetSampleCount: 1000)
                let features = analyzer.extractFeatures(from: normalizedBuffer)
                let segments = analyzer.calculateSegments(from: features)
                return (samples, features, segments)
            }.value

            await MainActor.run {
                self.waveformSamples = samples
                self.audioFeatures = features
                self.segments = segments
                self.isLoading = false
                self.isAnalyzing = false
                print("MainViewModel: Normalization and Re-analysis complete.")
            }
        }
    }
}
