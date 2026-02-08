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
        guard let assetAudioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            throw ExportError.audioFileNotFound
        }
        
        var currentTime = CMTime.zero
        var trackTimeRanges: [CMTimeRange] = []
        
        for segment in segments {
            if segment.isExcludedFromExport { continue }
            
            let start = CMTime(seconds: segment.startTime, preferredTimescale: 600)
            let duration = CMTime(seconds: segment.duration, preferredTimescale: 600)
            let range = CMTimeRange(start: start, duration: duration)
            
            try compositionAudioTrack.insertTimeRange(range, of: assetAudioTrack, at: currentTime)
            
            // 後で音量を調整するために、合成後のトラックにおける時間範囲を記録
            trackTimeRanges.append(CMTimeRange(start: currentTime, duration: duration))
            
            currentTime = CMTimeAdd(currentTime, duration)
        }
        
        // 音量調整用のAudioMix作成
        let audioMix = AVMutableAudioMix()
        let inputParameters = AVMutableAudioMixInputParameters(track: compositionAudioTrack)
        if isConversation {
            // 会話の場合は音量を1.5倍に設定
            inputParameters.setVolume(1.5, at: .zero)
        } else {
            inputParameters.setVolume(1.0, at: .zero)
        }
        audioMix.inputParameters = [inputParameters]
        
        // エクスポート設定
        // 会話の場合はビットレートを下げた設定を使用するために AVAssetWriter を検討するが、
        // 実装のシンプルさを優先しつつ、AVAssetExportSession で音量調整を適用する。
        // ビットレートの厳密な制御が必要な場合は AVAssetWriter に移行するが、
        // まずは音量調整を確実に実装する。
        
        guard let exportSession = AVAssetExportSession(asset: composition, presetName: AVAssetExportPresetAppleM4A) else {
            throw ExportError.exportFailed(nil)
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .m4a
        exportSession.audioMix = audioMix
        
        // 注意: AVAssetExportSession のプリセットではビットレートを直接数値で指定できない。
        // 会話用の低ビットレートが必要な場合は、ここで AVAssetWriter を使用するように書き換える。
        // ユーザーの要望に応えるため、AVAssetWriter による実装に切り替える。
        
        try await performAssetWriterExport(asset: composition, audioMix: audioMix, outputURL: outputURL, isConversation: isConversation)
    }
    
    private func performAssetWriterExport(asset: AVAsset, audioMix: AVAudioMix, outputURL: URL, isConversation: Bool) async throws {
        // 既存ファイルを削除
        if FileManager.default.fileExists(atPath: outputURL.path) {
            try? FileManager.default.removeItem(at: outputURL)
        }
        
        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        
        // ビットレートの設定 (会話は 64kbps, 通常は 128kbps or 192kbps)
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
        let track = try await asset.loadTracks(withMediaType: .audio)[0]
        
        // 音量調整を適用するために AVAssetReaderAudioMixOutput を使用
        let readerOutput = AVAssetReaderAudioMixOutput(audioTracks: [track], audioSettings: nil)
        readerOutput.audioMix = audioMix
        reader.add(readerOutput)
        
        writer.startWriting()
        writer.startSession(atSourceTime: .zero)
        reader.startReading()
        
        let queue = DispatchQueue(label: "com.rehearsallink.export.queue")
        
        // Swift 6 strict concurrency requires @Sendable closures for these types.
        // Since we are using these objects within a controlled sequence, we use a wrapper.
        struct ExportContext: @unchecked Sendable {
            let writer: AVAssetWriter
            let writerInput: AVAssetWriterInput
            let reader: AVAssetReader
            let readerOutput: AVAssetReaderAudioMixOutput
        }
        let context = ExportContext(writer: writer, writerInput: writerInput, reader: reader, readerOutput: readerOutput)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            context.writerInput.requestMediaDataWhenReady(on: queue) {
                while context.writerInput.isReadyForMoreMediaData {
                    if context.reader.status == .reading, let buffer = context.readerOutput.copyNextSampleBuffer() {
                        context.writerInput.append(buffer)
                    } else {
                        context.writerInput.markAsFinished()
                        
                        if context.reader.status == .failed {
                            continuation.resume(throwing: context.reader.error ?? ExportError.exportFailed(nil))
                        } else {
                            context.writer.finishWriting {
                                if context.writer.status == .completed {
                                    continuation.resume()
                                } else {
                                    continuation.resume(throwing: context.writer.error ?? ExportError.exportFailed(nil))
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