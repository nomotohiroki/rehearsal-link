import Foundation
import SwiftUI
import Combine

@MainActor
class MainViewModel: ObservableObject {
    @Published var audioData: AudioData?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var waveformSamples: [WaveformSample] = []
    @Published var audioFeatures: [AudioFeaturePoint] = []
    @Published var segments: [AudioSegment] = []
    @Published var selectedSegmentId: UUID?
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var isLoopingEnabled = false
    
    @Published var zoomLevel: Double = 1.0 // 1.0 = fit to width
    
    private let audioLoadService = AudioLoadService()
    private let waveformAnalyzer = WaveformAnalyzer()
    private let audioPlayerService = AudioPlayerService()
    private let projectService = ProjectService()
    private let exportService = ExportService()
    
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
                print("MainViewModel: AudioData set. Duration: \(data.duration)")
                
                let samples = waveformAnalyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
                self.waveformSamples = samples
                print("MainViewModel: Waveform samples updated.")
                
                // 特徴量抽出
                let features = waveformAnalyzer.extractFeatures(from: data.pcmBuffer)
                self.audioFeatures = features
                print("MainViewModel: Audio features extracted. Count: \(features.count)")
                if let first = features.first {
                    print("MainViewModel: First feature - Time: \(first.time), RMS: \(first.rms)")
                }
                
                // セグメント判定
                let segments = waveformAnalyzer.calculateSegments(from: features)
                self.segments = segments
                print("MainViewModel: Segments calculated. Count: \(segments.count)")
                for segment in segments {
                    print("MainViewModel: Segment - \(segment.type.rawValue): \(String(format: "%.2f", segment.startTime))s - \(String(format: "%.2f", segment.endTime))s")
                }
                
                // プレイヤーにロード
                audioPlayerService.load(url: data.url)
            } catch AudioLoadService.AudioLoadError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "ファイルの読み込みに失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
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
                let data = try audioLoadService.loadAudio(from: project.audioFileURL)
                self.audioData = data
                
                let samples = waveformAnalyzer.generateWaveformSamples(from: data.pcmBuffer, targetSampleCount: 1000)
                self.waveformSamples = samples
                
                // セグメント情報を復元
                self.segments = project.segments
                
                // プレイヤーにロード
                audioPlayerService.load(url: data.url)
            } catch ProjectService.ProjectError.fileSelectionCancelled {
                // Ignore
            } catch {
                self.errorMessage = "プロジェクトの読み込みに失敗しました: \(error.localizedDescription)"
            }
            isLoading = false
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
