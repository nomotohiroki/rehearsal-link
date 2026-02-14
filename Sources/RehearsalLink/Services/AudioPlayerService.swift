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

    private func scheduleSegment(from time: TimeInterval, to endTime: TimeInterval? = nil) {
        guard let file = audioFile else { return }

        playerNode.stop()

        let sampleRate = file.processingFormat.sampleRate
        let end = endTime ?? fileDuration
        
        let startFrame = max(0, AVAudioFramePosition(time * sampleRate))
        let endFrame = min(AVAudioFramePosition(end * sampleRate), file.length)
        
        var frameCount = endFrame - startFrame
        if frameCount < 0 { frameCount = 0 }

        guard frameCount > 0 else { return }

        // Schedule the specific segment
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: AVAudioFrameCount(frameCount), at: nil) { [weak self] in
            // This closure is called when the segment finishes playing.
            DispatchQueue.main.async {
                if self?.isLooping == true, let range = self?.loopRange {
                    self?.seek(to: range.lowerBound)
                    // After seeking, we need to play again
                    self?.play()
                } else {
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

        // Resume from current time
        scheduleSegment(from: currentTime)
        playerNode.play()
        isPlaying = true
        startTimer()
    }

    func pause() {
        guard isPlaying else { return }
        playerNode.pause()
        isPlaying = false
        stopTimer()
    }

    func stop() {
        if isPlaying {
            playerNode.stop()
        }
        isPlaying = false
        stopTimer()
        // Resetting time on stop might be desired behavior in some cases, here we keep it.
        // currentTime = 0
        // segmentStartTime = 0
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
            // If paused, just update the schedule for the next play
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
            currentTime = min(newCurrentTime, fileDuration)
        }
    }
}
