import Foundation
@preconcurrency import AVFoundation

actor ExportService {
    enum ExportError: Error {
        case fileSelectionCancelled
        case exportFailed(Error?)
        case noSegments
        case audioFileNotFound
        case initializationFailed
    }
    
    func exportSegments(audioURL: URL, segments: [AudioSegment], outputURL: URL, isConversation: Bool = false) async throws {
        let composition = AVMutableComposition()
        guard let compositionAudioTrack = composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid) else {
            throw ExportError.exportFailed(nil)
        }
        
        let asset = AVURLAsset(url: audioURL)
        // Load track in a way that's compatible with Swift 6
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let assetAudioTrack = tracks.first else {
            throw ExportError.audioFileNotFound
        }
        
        var currentTime = CMTime.zero
        
        for segment in segments {
            let start = CMTime(seconds: segment.startTime, preferredTimescale: 600)
            let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
            let range = CMTimeRange(start: start, duration: duration)
            
            try compositionAudioTrack.insertTimeRange(range, of: assetAudioTrack, at: currentTime)
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // 音量調整用のAudioMix作成
        let audioMix = AVMutableAudioMix()
        let inputParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
        if isConversation {
            inputParameters.setVolume(1.5, at: .zero)
        } else {
            inputParameters.setVolume(1.0, at: .zero)
        }
        audioMix.inputParameters = [inputParameters]
        
        try await performAssetWriterExport(asset: composition, audioMix: audioMix, outputURL: outputURL, isConversation: isConversation)
    }
    
    private func performAssetWriterExport(asset: AVAsset, audioMix: AVAudioMix, outputURL: URL, isConversation: Bool) async throws {
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let bitrate = isConversation ? 64000 : 192000
        let outputSettings: [String: Any] = [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVNumberOfChannelsKey: 2,
            AVSampleRateKey: 44100,
            AVEncoderBitRateKey: bitrate
        ]
        
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: outputSettings)
        writer.add(writerInput)
        
        let reader = try AVAssetReader(asset: asset)
        let tracks = try await asset.loadTracks(withMediaType: .audio)
        guard let track = tracks.first else { throw ExportError.audioFileNotFound }
        
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: nil)
        readerOutput.audioMix = audioMix
        reader.add(readerOutput)
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        reader.startReading()
        
        let queue = DispatchQueue(label: "com.rehearsallink.export.queue")
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            writerInput.requestMediaDataWhenReady(on: queue) {
                // Swift 6 warning workaround: access non-sendable objects within this closure
                while writerInput.isReadyForMoreMediaData {
                    if reader.status == .reading, let buffer = readerOutput.copyNextSampleBuffer() {
                        writerInput.append(buffer)
                    } else {
                        writerInput.markAsFinished()
                        if reader.status == .failed {
                            continuation.resume(throwing: reader.error ?? ExportError.exportFailed(nil))
                        } else {
                            writer.finishWriting {
                                if writer.status == .completed {
                                    continuation.resume()
                                } else {
                                    continuation.resume(throwing: writer.error ?? ExportError.exportFailed(nil))
                                }
                            }
                        }
                        break
                    }
                }
            }
        }
    }
}

// MARK: - Sendable Conformance for AVFoundation Classes
// AVFoundation classes are not yet Sendable in Swift 6, but we are ensuring thread safety
// by using a serial DispatchQueue for the export process.
extension AVAssetReader: @retroactive @unchecked Sendable {}
extension AVAssetWriter: @retroactive @unchecked Sendable {}
extension AVAssetWriterInput: @retroactive @unchecked Sendable {}
extension AVAssetReaderAudioMixOutput: @retroactive @unchecked Sendable {}
