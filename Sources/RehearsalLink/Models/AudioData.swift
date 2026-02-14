import AVFoundation
import Foundation

struct AudioData: @unchecked Sendable {
    let url: URL
    let fileName: String
    let duration: TimeInterval
    let sampleRate: Double
    let channelCount: AVAudioChannelCount
    let audioFile: AVAudioFile

    init(url: URL, audioFile: AVAudioFile) {
        self.url = url
        self.fileName = url.lastPathComponent
        self.audioFile = audioFile

        let format = audioFile.processingFormat
        self.sampleRate = format.sampleRate
        self.channelCount = format.channelCount
        self.duration = Double(audioFile.length) / format.sampleRate
    }
}
