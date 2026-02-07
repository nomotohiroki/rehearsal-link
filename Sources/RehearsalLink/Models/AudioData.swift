import Foundation
import AVFoundation

struct AudioData {
    let url: URL
    let fileName: String
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: AVAudioChannelCount
    let pcmBuffer: AVAudioPCMBuffer
    
    init(url: URL, pcmBuffer: AVAudioPCMBuffer) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.pcmBuffer = pcmBuffer
        self.sampleRate = pcmBuffer.format.sampleRate
        self.channelCount = pcmBuffer.format.channelCount
        self.duration = Double(pcmBuffer.frameLength) / pcmBuffer.format.sampleRate
    }
}
