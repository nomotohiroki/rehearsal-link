import Foundation
import AVFoundation
import Combine

import Foundation
import AVFoundation
import Combine

@MainActor
class AudioPlayerService: ObservableObject {
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0
    @Published var isLooping = false
    var loopRange: ClosedRange<TimeInterval>?
    
    private var timer: Timer?
    private var duration: TimeInterval = 0
    private var audioFile: AVAudioFile?
    private var startSampleTime: Double = 0
    
    init() {
        engine.attach(playerNode)
        engine.connect(playerNode, to: engine.mainMixerNode, format: nil)
        
        do {
            try engine.start()
        } catch {
            print("AudioPlayerService: Failed to start audio engine: \(error)")
        }
    }
    
    func load(buffer: AVAudioPCMBuffer) {
        // We still take buffer for consistency, but we'll use the file for playback if possible.
        // In a real app, we might pass the URL here.
        // For now, let's assume we need to load the file separately or change the signature.
    }
    
    func load(url: URL) {
        stop()
        
        do {
            let file = try AVAudioFile(forReading: url)
            self.audioFile = file
            self.duration = Double(file.length) / file.processingFormat.sampleRate
            
            engine.disconnectNodeInput(engine.mainMixerNode)
            engine.connect(playerNode, to: engine.mainMixerNode, format: file.processingFormat)
            
            scheduleBuffer(from: 0)
        } catch {
            print("AudioPlayerService: Failed to load audio file: \(error)")
        }
    }
    
    private func scheduleBuffer(from time: TimeInterval) {
        guard let file = audioFile else { return }
        
        let sampleRate = file.processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(time * sampleRate)
        let frameCount = AVAudioFrameCount(file.length) - AVAudioFrameCount(startFrame)
        
        guard frameCount > 0 else { return }
        
        playerNode.stop()
        playerNode.scheduleSegment(file, startingFrame: startFrame, frameCount: frameCount, at: nil) {
            // Completed
        }
        
        startSampleTime = Double(startFrame) / sampleRate
    }
    
    func play() {
        guard !isPlaying, audioFile != nil else { return }
        
        if !engine.isRunning {
            try? engine.start()
        }
        
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
        playerNode.stop()
        isPlaying = false
        currentTime = 0
        startSampleTime = 0
        stopTimer()
        
        if audioFile != nil {
            scheduleBuffer(from: 0)
        }
    }
    
    func seek(to time: TimeInterval) {
        let wasPlaying = isPlaying
        playerNode.stop() // Need to stop to reschedule
        
        currentTime = max(0, min(time, duration))
        scheduleBuffer(from: currentTime)
        startSampleTime = currentTime
        
        if wasPlaying {
            playerNode.play()
            isPlaying = true
            startTimer()
        } else {
            isPlaying = false
            stopTimer()
        }
    }
    
    private func startTimer() {
        stopTimer()
        timer = Timer.scheduledTimer(withTimeInterval: 1.0/60.0, repeats: true) { [weak self] _ in
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
        guard isPlaying, let lastRenderTime = playerNode.lastRenderTime,
              let playerTime = playerNode.playerTime(forNodeTime: lastRenderTime) else {
            return
        }
        
        let sampleRate = playerTime.sampleRate
        if sampleRate > 0 {
            let relativeTime = Double(playerTime.sampleTime) / sampleRate
            let newTime = startSampleTime + relativeTime
            if newTime.isFinite {
                // Handle looping
                if isLooping, let range = loopRange {
                    if newTime >= range.upperBound {
                        seek(to: range.lowerBound)
                        return
                    }
                }
                
                currentTime = newTime
            }
        }
    }
}
