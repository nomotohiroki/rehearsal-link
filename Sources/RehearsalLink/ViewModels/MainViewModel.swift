import Foundation
import SwiftUI
import Combine

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
    
    @Published var zoomLevel: Double = 1.0 // 1.0 = fit to width
    
    private let audioLoadService = AudioLoadService()
    private let waveformAnalyzer = WaveformAnalyzer()
    private let audioPlayerService = AudioPlayerService()
    private let projectService = ProjectService()
    private let exportService = ExportService()
    private let transcriptionService = SpeechTranscriptionService()
    
    private var cancellables = Set<AnyCancellable>()
    
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
            audioPlayerService.loopRange = segment.startTime...segment.endTime
        } else {
            audioPlayerService.loopRange = nil
        }
    }
    
    func selectFile() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                print("MainViewModel: Starting load...")
                let data = try await audioLoadService.selectAndLoadFile()
                self.audioData = data
                self.isLoading = false
                self.isAnalyzing = true
                print("MainViewModel: AudioData set. Duration: \(data.duration)")
                
                // プレイヤーにロード（先に再生可能な状態にする）
                audioPlayerService.load(url: data.url)

                // 重い解析処理をバックグラウンドで行う
                // Task.detachedを使用してMainActorから切り離す
                let analyzer = self.waveformAnalyzer
                let (samples, features, segments) = await Task.detached(priority: .userInitiated) {
                    let samples = analyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
                    let features = analyzer.extractFeatures(from: data.pcmBuffer)
                    let segments = analyzer.calculateSegments(from: features)
                    return (samples, features, segments)
                }.value

                self.waveformSamples = samples
                self.audioFeatures = features
                self.segments = segments
                self.isAnalyzing = false
                
                print("MainViewModel: Analysis complete.")
            } catch AudioLoadService.AudioLoadError.fileSelectionCancelled {
                isLoading = false
                isAnalyzing = false
            } catch {
                self.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
                isLoading = false
                isAnalyzing = false
            }
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
    
    func updateSegmentType(id: UUID, type: SegmentType) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: type,
                label: oldSegment.label
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
                label: label.isEmpty ? nil : label
            )
        }
    }
    
    func moveBoundary(index: Int, newTime: TimeInterval) {
        guard index >= 0 && index < segments.count - 1 else { return }
        
        let minTime = index > 0 ? segments[index-1].endTime + 0.1 : 0.1
        let maxTime = segments[index+1].endTime - 0.1
        
        let clampedTime = max(minTime, min(newTime, maxTime))
        
        let left = segments[index]
        let right = segments[index+1]
        
        segments[index] = AudioSegment(id: left.id, startTime: left.startTime, endTime: clampedTime, type: left.type, label: left.label)
        segments[index+1] = AudioSegment(id: right.id, startTime: clampedTime, endTime: right.endTime, type: right.type, label: right.label)
    }
    
    func splitSegment(at time: TimeInterval) {
        guard let index = segments.firstIndex(where: { time > $0.startTime && time < $0.endTime }) else {
            return
        }
        
        let segment = segments[index]
        // 極端に短いセグメントができないようにチェック
        guard time - segment.startTime > 0.1 && segment.endTime - time > 0.1 else {
            return
        }
        
        let left = AudioSegment(startTime: segment.startTime, endTime: time, type: segment.type)
        let right = AudioSegment(startTime: time, endTime: segment.endTime, type: segment.type)
        
        segments.remove(at: index)
        segments.insert(right, at: index)
        segments.insert(left, at: index)
    }
    
    func transcribeSegment(id: UUID) {
        guard let index = segments.firstIndex(where: { $0.id == id }),
              let audioData = audioData else { return }
        
        let segment = segments[index]
        guard segment.type == .conversation else { return }
        
        isTranscribing = true
        errorMessage = nil
        
        Task {
            do {
                let text = try await transcriptionService.transcribe(
                    audioURL: audioData.url,
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
                            transcription: text
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
    
    func saveProject() {
        guard let audioData = audioData else { return }
        Task {
            do {
                try await projectService.saveProject(audioFileURL: audioData.url, segments: segments)
            } catch ProjectService.ProjectError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "プロジェクトの保存に失敗しました: \(error.localizedDescription)"
            }
        }
    }
    
    func loadProject() {
        Task {
            isLoading = true
            errorMessage = nil
            do {
                let project = try await projectService.loadProject()
                
                // オーディオファイルの読み込み
                let data = try await audioLoadService.loadAudio(from: project.audioFileURL)
                self.audioData = data
                self.isLoading = false
                self.isAnalyzing = true
                
                // セグメント情報はプロジェクトから取得（解析を待たずに表示可能）
                self.segments = project.segments
                
                // プレイヤーにロード
                audioPlayerService.load(url: data.url)

                // 波形のみバックグラウンドで解析
                let analyzer = self.waveformAnalyzer
                let samples = await Task.detached(priority: .userInitiated) {
                    return analyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
                }.value
                
                self.waveformSamples = samples
                self.isAnalyzing = false
            } catch ProjectService.ProjectError.fileSelectionCancelled {
                isLoading = false
                isAnalyzing = false
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
            self.errorMessage = "書き出すセグメントが見つかりません。"
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
}
