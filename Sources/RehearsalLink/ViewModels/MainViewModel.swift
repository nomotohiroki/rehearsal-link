import Combine
import Foundation
import SwiftUI
import AVFoundation
import Accelerate

@MainActor
class MainViewModel: ObservableObject {
    @Published var audioData: AudioData?
    @Published var isLoading = false
    @Published var isAnalyzing = false
    @Published var errorMessage: String?
    @Published var waveformSamples: [WaveformSample] = []
    @Published var audioFeatures: [AudioFeaturePoint] = []
    @Published var segments: [AudioSegment] = []
    @Published var projectSummary: String?
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
    var transcriptionService: SpeechTranscriptionService?

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
        
        // SpeechTranscriptionServiceの初期化
        do {
            transcriptionService = try SpeechTranscriptionService()
        } catch {
            self.errorMessage = "文字起こしサービスの初期化に失敗しました。アプリを再起動してください。"
            print("Failed to initialize SpeechTranscriptionService: \(error)")
        }
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
        try audioPlayerService.load(data: data)

        // 重い解析処理をバックグラウンドで行う
        let analyzer = waveformAnalyzer
        let result: Result<(samples: [WaveformSample], features: [AudioFeaturePoint], segments: [AudioSegment]), Error> = await Task.detached(priority: .userInitiated) {
            do {
                let samples = try analyzer.generateWaveformSamples(from: data.audioFile, targetSampleCount: 1000)
                let features = try analyzer.extractFeatures(from: data.audioFile)
                let segments = analyzer.calculateSegments(from: features)
                return .success((samples, features, segments))
            } catch {
                print("MainViewModel: Analysis failed with error: \(error)")
                return .failure(error)
            }
        }.value

        switch result {
        case let .success((samples, features, segments)):
            self.waveformSamples = samples
            self.audioFeatures = features
            self.segments = segments
        case let .failure(error):
            self.errorMessage = "音声ファイルの解析に失敗しました: \(error.localizedDescription)"
        }

        isAnalyzing = false
        print("MainViewModel: Analysis complete.")
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
        guard let audioData = audioData else { return }

        self.isLoading = true
        self.isAnalyzing = true
        self.errorMessage = nil

        Task.detached(priority: .userInitiated) {
            let inputFile = audioData.audioFile
            let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathExtension("m4a")

            do {
                // --- Pass 1: Calculate overall RMS to determine gain ---
                var sumOfSquares: Double = 0
                let frameLength = inputFile.length
                let format = inputFile.processingFormat
                let channelCount = format.channelCount
                
                inputFile.framePosition = 0
                let bufferSize = AVAudioFrameCount(4096)
                guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: bufferSize) else {
                    throw URLError(.cannotCreateFile)
                }

                while inputFile.framePosition < frameLength {
                    try inputFile.read(into: buffer)
                    guard let floatData = buffer.floatChannelData else { continue }
                    
                    for channel in 0..<Int(channelCount) {
                        var channelSumOfSquares: Float = 0
                        vDSP_svesq(floatData[channel], 1, &channelSumOfSquares, vDSP_Length(buffer.frameLength))
                        sumOfSquares += Double(channelSumOfSquares)
                    }
                }
                
                let totalSamples = Double(frameLength) * Double(channelCount)
                let meanSquare = sumOfSquares / totalSamples
                let rootMeanSquare = sqrt(meanSquare)
                
                // --- Calculate Gain ---
                let targetRMSDecibels: Float = -20.0
                let targetRMS = pow(10.0, targetRMSDecibels / 20.0)
                var gain = targetRMS / Float(rootMeanSquare)
                gain = min(gain, 1000.0) // Clamp gain to avoid excessive amplification

                // --- Pass 2: Apply gain and write to new file ---
                let outputSettings = inputFile.processingFormat.settings
                let outputFile = try AVAudioFile(forWriting: tempURL, settings: outputSettings)
                
                inputFile.framePosition = 0
                
                while inputFile.framePosition < frameLength {
                    try inputFile.read(into: buffer)
                    
                    guard let processedBuffer = self.audioProcessor.applyGain(buffer: buffer, gain: gain) else {
                        throw URLError(.cannotCreateFile)
                    }
                    try outputFile.write(from: processedBuffer)
                }
                
                // --- Load the new normalized file ---
                await MainActor.run {
                    self.handleFile(at: tempURL)
                }

            } catch {
                await MainActor.run {
                    self.errorMessage = "正規化処理に失敗しました: \(error.localizedDescription)"
                    self.isLoading = false
                    self.isAnalyzing = false
                }
            }
        }
    }

    // ユーティリティ: 時間フォーマット (MM:SS)
    func formatShortTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
