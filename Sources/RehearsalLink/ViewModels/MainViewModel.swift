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
    @Published var isBatchTranscribing = false
    @Published var batchTranscriptionProgress: Double = 0
    
    @Published var zoomLevel: Double = 1.0 // 1.0 = fit to width
    
    @Published var showProjectDetectedAlert = false
    private var pendingAudioURL: URL?
    private var pendingProjectURL: URL?
    
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
            do {
                let audioURL = try await audioLoadService.selectAudioFile()
                
                // プロジェクトファイルの候補を複数チェック
                let baseURL = audioURL.deletingPathExtension()
                let projectURL = baseURL.appendingPathExtension("rehearsallink")
                let projectJSONURL = baseURL.appendingPathExtension("rehearsallink").appendingPathExtension("json")
                
                if FileManager.default.fileExists(atPath: projectURL.path) {
                    self.pendingAudioURL = audioURL
                    self.pendingProjectURL = projectURL
                    self.showProjectDetectedAlert = true
                } else if FileManager.default.fileExists(atPath: projectJSONURL.path) {
                    self.pendingAudioURL = audioURL
                    self.pendingProjectURL = projectJSONURL
                    self.showProjectDetectedAlert = true
                } else {
                    try await performLoadAudio(from: audioURL)
                }
            } catch AudioLoadService.AudioLoadError.fileSelectionCancelled {
                // Ignore
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
        self.audioData = data
        self.isLoading = false
        self.isAnalyzing = true
        print("MainViewModel: AudioData set. Duration: \(data.duration)")
        
        // プレイヤーにロード
        audioPlayerService.load(url: data.url)

        // 重い解析処理をバックグラウンドで行う
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
    }

    private func performLoadProject(_ project: RehearsalLinkProject) async throws {
        isLoading = true
        errorMessage = nil
        
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
    
    func updateTranscription(id: UUID, text: String) {
        if let index = segments.firstIndex(where: { $0.id == id }) {
            let oldSegment = segments[index]
            segments[index] = AudioSegment(
                id: oldSegment.id,
                startTime: oldSegment.startTime,
                endTime: oldSegment.endTime,
                type: oldSegment.type,
                label: oldSegment.label,
                transcription: text
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
            transcription: mergedTranscription
        )
        
        segments.remove(at: index + 1)
        segments[index] = mergedSegment
        
        // 結合後のセグメントを選択
        selectedSegmentId = mergedSegment.id
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
    
    func transcribeAllConversations() {
        guard let audioData = audioData else { return }
        
        let conversationSegments = segments.filter { $0.type == .conversation && $0.transcription == nil }
        guard !conversationSegments.isEmpty else { return }
        
        isBatchTranscribing = true
        batchTranscriptionProgress = 0
        errorMessage = nil
        
        Task {
            var completedCount = 0
            let totalCount = conversationSegments.count
            
            for segment in conversationSegments {
                // 連続実行による負荷を軽減するため、各処理の間にわずかな空きを作る
                await Task.yield()
                
                do {
                    let text = try await transcriptionService.transcribe(
                        audioURL: audioData.url,
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
                                transcription: text
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
            self.errorMessage = "文字起こし済みのセグメントがありません。"
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
    
    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
