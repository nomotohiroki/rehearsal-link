import AVFoundation
import Foundation

struct AudioData: @unchecked Sendable {
    let url: URL
    let fileName: String
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: AVAudioChannelCount
    let pcmBuffer: AVAudioPCMBuffer

    init(url: URL, pcmBuffer: AVAudioPCMBuffer) {
        self.url = url
        fileName = url.lastPathComponent
        self.pcmBuffer = pcmBuffer
        sampleRate = pcmBuffer.format.sampleRate
        channelCount = pcmBuffer.format.channelCount
        duration = Double(pcmBuffer.frameLength) / pcmBuffer.format.sampleRate
    }
}
