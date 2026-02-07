import Foundation
import AVFoundation
import Accelerate

struct WaveformSample: Identifiable {
    let id = UUID()
    let min: Float
    let max: Float
}

struct AudioFeaturePoint {
    let time: TimeInterval
    let rms: Float
    let lowFrequencyEnergy: Float // For speech detection (simple)
    let highFrequencyEnergy: Float
}

@MainActor
class WaveformAnalyzer {
    /// PCMバッファから指定されたサンプル数分の波形データを抽出します
    func generateWaveformSamples(from buffer: AVAudioPCMBuffer, targetSampleCount: Int) -> [WaveformSample] {
        print("WaveformAnalyzer: Starting analysis. FrameLength: \(buffer.frameLength), Channels: \(buffer.format.channelCount)")
        
        guard targetSampleCount > 0 else { return [] }
        guard buffer.frameLength > 0 else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        
        // Ensure channel count is reasonable
        guard channelCount > 0 else { return [] }
        
        // Safety check for pointer
        guard let floatData = buffer.floatChannelData else {
            print("WaveformAnalyzer: floatChannelData is nil. Format might not be Float32.")
            return []
        }
        
        let samplesPerPixel = max(1, frameLength / targetSampleCount)
        var samples: [WaveformSample] = []
        samples.reserveCapacity(targetSampleCount)
        
        // Use UnsafeBufferPointer for safer access to channel pointers
        let channelPointers = UnsafeBufferPointer(start: floatData, count: channelCount)
        
        for i in 0..<targetSampleCount {
            let startFrame = i * samplesPerPixel
            let endFrame = min(startFrame + samplesPerPixel, frameLength)
            
            if startFrame >= frameLength { break }
            
            var localMin: Float = 0
            var localMax: Float = 0
            var firstSample = true
            
            for channel in 0..<channelCount {
                let channelData = channelPointers[channel]
                
                let countToRead = endFrame - startFrame
                if countToRead <= 0 { continue }
                
                let currentPtr = channelData.advanced(by: startFrame)
                
                // Use Accelerate for min/max if possible, but for small chunks direct loop is okay.
                // For simplicity and to match existing logic, keeping direct loop for now.
                for j in 0..<countToRead {
                    let value = currentPtr[j]
                    if firstSample {
                        localMin = value
                        localMax = value
                        firstSample = false
                    } else {
                        if value < localMin { localMin = value }
                        if value > localMax { localMax = value }
                    }
                }
            }
            
            samples.append(WaveformSample(min: localMin, max: localMax))
        }
        
        print("WaveformAnalyzer: Finished. Generated \(samples.count) samples.")
        return samples
    }
    
    /// 音響特徴量（RMSおよび簡易周波数分析）を抽出します
    func extractFeatures(from buffer: AVAudioPCMBuffer, windowSize: Int = 4096, hopSize: Int = 2048) -> [AudioFeaturePoint] {
        guard buffer.frameLength > 0 else { return [] }
        
        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate
        
        guard let floatData = buffer.floatChannelData else { return [] }
        
        // モノラルとして処理するために平均化、あるいは1ch目のみ使用
        // ここでは1ch目のみを使用して計算を簡略化
        let channelData = floatData[0]
        
        var features: [AudioFeaturePoint] = []
        
        // FFT準備
        let log2n = UInt(round(log2(Double(windowSize))))
        let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
        defer { vDSP_destroy_fftsetup(fftSetup) }
        
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))
        
        var realp = [Float](repeating: 0, count: windowSize / 2)
        var imagp = [Float](repeating: 0, count: windowSize / 2)
        
        realp.withUnsafeMutableBufferPointer { realPtr in
            imagp.withUnsafeMutableBufferPointer { imagPtr in
                var output = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)
                
                for startFrame in stride(from: 0, to: frameLength - windowSize, by: hopSize) {
                    let currentPtr = channelData.advanced(by: startFrame)
                    
                    // 1. RMS計算
                    var rms: Float = 0
                    vDSP_rmsqv(currentPtr, 1, &rms, vDSP_Length(windowSize))
                    
                    // 2. FFT分析 (簡易版)
                    // 窓関数適用
                    var windowedSamples = [Float](repeating: 0, count: windowSize)
                    vDSP_vmul(currentPtr, 1, window, 1, &windowedSamples, 1, vDSP_Length(windowSize))
                    
                    // 実数FFT
                    windowedSamples.withUnsafeBufferPointer { bufferPtr in
                        let complexPtr = UnsafeRawPointer(bufferPtr.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(complexPtr, 2, &output, 1, vDSP_Length(windowSize / 2))
                    }
                    
                    vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))
                    
                    // パワースペクトル計算
                    var magnitudes = [Float](repeating: 0, count: windowSize / 2)
                    vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(windowSize / 2))
                    
                    // スペクトルを周波数帯域で分割 (簡易的な会話帯域判定用)
                    let binFreq = Float(sampleRate) / Float(windowSize)
                    let speechLowBin = Int(300 / binFreq)
                    let speechHighBin = Int(3500 / binFreq)
                    
                    var lowEnergy: Float = 0
                    var highEnergy: Float = 0
                    
                    if speechHighBin < magnitudes.count {
                        magnitudes.withUnsafeBufferPointer { magPtr in
                            vDSP_sve(magPtr.baseAddress!.advanced(by: speechLowBin), 1, &lowEnergy, vDSP_Length(speechHighBin - speechLowBin))
                            vDSP_sve(magPtr.baseAddress!.advanced(by: speechHighBin), 1, &highEnergy, vDSP_Length(magnitudes.count - speechHighBin))
                        }
                    }
                    
                    let time = Double(startFrame) / sampleRate
                    features.append(AudioFeaturePoint(
                        time: time,
                        rms: rms,
                        lowFrequencyEnergy: lowEnergy,
                        highFrequencyEnergy: highEnergy
                    ))
                }
            }
        }
        
        return features
    }
    
    /// 抽出された特徴量からセグメント（演奏・会話・無音）を判定します
    func calculateSegments(from features: [AudioFeaturePoint]) -> [AudioSegment] {
        guard !features.isEmpty else { return [] }
        
        // Thresholds adjusted for better sensitivity
        let silenceThreshold: Float = 0.0015
        let performanceThreshold: Float = 0.03
        
        // 1. 各ポイントごとの暫定判定
        var rawSegments: [AudioSegment] = []
        var currentType: SegmentType = .silence
        var startTime: TimeInterval = features[0].time
        
        for feature in features {
            let type: SegmentType
            
            if feature.rms < silenceThreshold {
                type = .silence
            } else if feature.rms > performanceThreshold {
                // 音量が大きい場合は演奏の可能性が高い
                type = .performance
            } else {
                // 中間の音量。高域エネルギーが相対的に強ければ演奏、そうでなければ会話とする簡易判定
                // Lowered the ratio threshold to capture more instrumental parts as performance
                if feature.highFrequencyEnergy > feature.lowFrequencyEnergy * 0.25 {
                    type = .performance
                } else {
                    type = .conversation
                }
            }
            
            if type != currentType {
                let endTime = feature.time
                if endTime > startTime {
                    rawSegments.append(AudioSegment(startTime: startTime, endTime: endTime, type: currentType))
                }
                currentType = type
                startTime = endTime
            }
        }
        
        // 最後のセグメントを追加
        if let lastFeature = features.last {
            rawSegments.append(AudioSegment(startTime: startTime, endTime: lastFeature.time, type: currentType))
        }
        
        // 2. 平滑化（短すぎる区間の除去と結合）
        return smoothSegments(rawSegments)
    }
    
    private func smoothSegments(_ segments: [AudioSegment]) -> [AudioSegment] {
        guard segments.count > 1 else { return segments }
        
        let minDuration: TimeInterval = 1.0 // 1秒未満の区間は無視して前後の区間に統合
        
        var smoothed: [AudioSegment] = []
        var current = segments[0]
        
        for i in 1..<segments.count {
            let next = segments[i]
            
            if next.duration < minDuration {
                // 次の区間が短すぎる場合は現在の区間に吸収させる
                current = AudioSegment(startTime: current.startTime, endTime: next.endTime, type: current.type)
            } else if current.duration < minDuration {
                // 現在の区間が短すぎる場合は次の区間に吸収させる（開始時間を早める）
                current = AudioSegment(startTime: current.startTime, endTime: next.endTime, type: next.type)
            } else if current.type == next.type {
                // 同じタイプが続く場合は結合
                current = AudioSegment(startTime: current.startTime, endTime: next.endTime, type: current.type)
            } else {
                smoothed.append(current)
                current = next
            }
        }
        smoothed.append(current)
        
        return smoothed
    }
}
