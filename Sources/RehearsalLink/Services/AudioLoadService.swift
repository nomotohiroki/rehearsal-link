import Foundation
import AVFoundation
import AppKit
import UniformTypeIdentifiers

class AudioLoadService {
    enum AudioLoadError: Error {
        case fileSelectionCancelled
        case failedToLoadFile(Error)
        case invalidFormat
    }
    
    @MainActor
    func selectAndLoadFile() async throws -> AudioData {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.audio, .mp3, .wav]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        let response = await openPanel.begin()
        guard response == .OK, let url = openPanel.url else {
            throw AudioLoadError.fileSelectionCancelled
        }
        
        return try loadAudio(from: url)
    }
    
    func loadAudio(from url: URL) throws -> AudioData {
        print("AudioLoadService: Loading file from \(url.lastPathComponent)")
        do {
            let file = try AVAudioFile(forReading: url)
            
            // 標準的なフォーマット（Float32, 非インターリーブ）を指定
            // これにより、m4aなどの圧縮ファイルも自動的に変換して読み込める
            guard let format = AVAudioFormat(standardFormatWithSampleRate: file.fileFormat.sampleRate, 
                                           channels: file.fileFormat.channelCount) else {
                throw AudioLoadError.invalidFormat
            }
            
            print("AudioLoadService: Standardized Format: \(format)")
            
            let frameCount = AVAudioFrameCount(file.length)
            print("AudioLoadService: File Length (frames): \(frameCount)")
            
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
                throw AudioLoadError.invalidFormat
            }
            
            try file.read(into: buffer)
            print("AudioLoadService: Read complete. Buffer frameLength: \(buffer.frameLength)")
            
            return AudioData(url: url, pcmBuffer: buffer)
        } catch {
            print("AudioLoadService: Failed to load. Error: \(error)")
            throw AudioLoadError.failedToLoadFile(error)
        }
    }
}
