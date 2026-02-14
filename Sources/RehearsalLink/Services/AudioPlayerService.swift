import AVFoundation
import Combine
import Foundation

@MainActor
class AudioPlayerService: ObservableObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()

    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var isLooping = false
    var loopRange: ClosedRange<TimeInterval>?

    private var timer: Timer?
    private var audioFile: AVAudioFile?
    private var fileDuration: TimeInterval = 0
    // The time offset of the currently scheduled segment
    private var segmentStartTime: TimeInterval = 0

    init() {
        engine.attach(playerNode)
        // The format will be connected on load
    }

    func load(data: AudioData) throws {
        stop()

        let file = data.audioFile
        self.audioFile = file
        self.fileDuration = data.duration
        self.currentTime = 0
        self.segmentStartTime = 0

        // Connect nodes with the correct format
        let format = file.processingFormat
        engine.connect(playerNode, to: engine.mainMixerNode, format: format)
        
        // Ensure engine is running
        if !engine.isRunning {
            try engine.start()
        }
    }

    private func scheduleSegment(from time: TimeInterval) {
        guard let file = audioFile else { return }

        playerNode.stop()

        let sampleRate = file.processingFormat.sampleRate
        
        // ループ中ならループ範囲の終端、そうでなければファイル末尾まで
        let end = (isLooping ? loopRange?.upperBound : nil) ?? fileDuration
        
        let startFrame = max(0, AVAudioFramePosition(time * sampleRate))
        let endFrame = min(AVAudioFramePosition(end * sampleRate), file.length)
        
        var frameCount = endFrame - startFrame
        if frameCount < 0 { frameCount = 0 }

        guard frameCount > 0 else { return }

        // Schedule the specific segment
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: AVAudioFrameCount(frameCount), at: nil) { [weak self] in
            // 完了時の処理はシンプルに：ループ中ならタイマーがseekをハンドルするので、ここでは何もしない。
            // ループ中でない場合のみ、再生終了処理を行う。
            DispatchQueue.main.async {
                if self?.isLooping == false {
                    self?.isPlaying = false
                    self?.stopTimer()
                }
            }
        }
        segmentStartTime = time
    }

    func play() {
        guard !isPlaying, audioFile != nil else { return }
        
        if !engine.isRunning {
            do {
                try engine.start()
            } catch {
                print("AudioPlayerService: Failed to start engine on play: \(error)")
                return
            }
        }

        // ループ範囲が設定されている場合、現在位置が範囲外なら開始位置に戻す
        if isLooping, let range = loopRange {
            if currentTime < range.lowerBound || currentTime >= range.upperBound - 0.05 {
                currentTime = range.lowerBound
            }
        }

        // Resume from current time
        scheduleSegment(from: currentTime)
        playerNode.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        playerNode.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        playerNode.stop()
        isPlaying = false
        stopTimer()
        
        // 停止時は位置をリセット（ループ範囲があればその開始位置、なければ0）
        if let range = loopRange {
            currentTime = range.lowerBound
        } else {
            currentTime = 0
        }
        segmentStartTime = currentTime
    }

    func seek(to time: TimeInterval) {
        let newTime = max(0, min(time, fileDuration))
        currentTime = newTime
        segmentStartTime = newTime

        if isPlaying {
            playerNode.stop()
            scheduleSegment(from: newTime)
            playerNode.play()
        } else {
            // 停止中/ポーズ中のシークでもスケジュールを更新しておく
            scheduleSegment(from: newTime)
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0 / 60.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updatePosition()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    private func updatePosition() {
        guard playerNode.isPlaying,
              let nodeTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: nodeTime)
        else {
            return
        }

        let newCurrentTime = segmentStartTime + (Double(playerTime.sampleTime) / playerTime.sampleRate)
        if newCurrentTime.isFinite && newCurrentTime >= 0 {
            // ループ処理
            if isLooping, let range = loopRange {
                if newCurrentTime >= range.upperBound {
                    seek(to: range.lowerBound)
                    return
                }
            }
            
            // ファイル末尾に到達
            if newCurrentTime >= fileDuration {
                stop()
                return
            }

            currentTime = newCurrentTime
        }
    }
}
