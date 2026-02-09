import Accelerate
import AVFoundation
import Foundation

struct WaveformSample: Identifiable {
    let id = UUID()
    let min: Float
    let max: Float
}

struct AudioFeaturePoint {
    let time: TimeInterval
    let rms: Float
    let lowFrequencyEnergy: Float // 300Hz - 4kHz (approximate speech range)
    let highFrequencyEnergy: Float // > 4kHz
    let spectralCentroid: Float
    let zeroCrossingRate: Float
}

struct WaveformAnalyzer: Sendable {
    /// PCMバッファから指定されたサンプル数分の波形データを抽出します
    func generateWaveformSamples(from buffer: AVAudioPCMBuffer, targetSampleCount: Int) -> [WaveformSample] {
        print("WaveformAnalyzer: Starting analysis. FrameLength: \(buffer.frameLength), Channels: \(buffer.format.channelCount)")

        guard targetSampleCount > 0, buffer.frameLength > 0 else { return [] }

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

        for i in 0 ..< targetSampleCount {
            let startFrame = i * samplesPerPixel
            let endFrame = min(startFrame + samplesPerPixel, frameLength)

            if startFrame >= frameLength { break }

            let (localMin, localMax) = calculateMinMax(
                channelPointers: channelPointers,
                channelCount: channelCount,
                startFrame: startFrame,
                endFrame: endFrame
            )
            samples.append(WaveformSample(min: localMin, max: localMax))
        }

        print("WaveformAnalyzer: Finished. Generated \(samples.count) samples.")
        return samples
    }

    private func calculateMinMax(
        channelPointers: UnsafeBufferPointer<UnsafeMutablePointer<Float>>,
        channelCount: Int,
        startFrame: Int,
        endFrame: Int
    ) -> (min: Float, max: Float) {
        var localMin: Float = 0
        var localMax: Float = 0
        var firstSample = true

        for channel in 0 ..< channelCount {
            let channelData = channelPointers[channel]
            let countToRead = endFrame - startFrame
            if countToRead <= 0 { continue }

            let currentPtr = channelData.advanced(by: startFrame)

            for j in 0 ..< countToRead {
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
        return (localMin, localMax)
    }

    /// 音響特徴量（RMSおよび周波数分析）を抽出します
    func extractFeatures(from buffer: AVAudioPCMBuffer, windowSize: Int = 4096, hopSize: Int = 2048) -> [AudioFeaturePoint] {
        guard buffer.frameLength > 0 else { return [] }

        let frameLength = Int(buffer.frameLength)
        let sampleRate = buffer.format.sampleRate

        guard let floatData = buffer.floatChannelData else { return [] }

        // モノラルとして処理
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

                    // 2. Zero Crossing Rate
                    var zcr: Float = 0
                    for j in 0 ..< windowSize - 1 {
                        if (currentPtr[j] < 0 && currentPtr[j + 1] >= 0) || (currentPtr[j] >= 0 && currentPtr[j + 1] < 0) {
                            zcr += 1
                        }
                    }
                    zcr /= Float(windowSize)

                    // 3. FFT分析
                    var windowedSamples = [Float](repeating: 0, count: windowSize)
                    vDSP_vmul(currentPtr, 1, window, 1, &windowedSamples, 1, vDSP_Length(windowSize))

                    windowedSamples.withUnsafeBufferPointer { bufferPtr in
                        let complexPtr = UnsafeRawPointer(bufferPtr.baseAddress!).assumingMemoryBound(to: DSPComplex.self)
                        vDSP_ctoz(complexPtr, 2, &output, 1, vDSP_Length(windowSize / 2))
                    }

                    vDSP_fft_zrip(fftSetup!, &output, 1, log2n, FFTDirection(FFT_FORWARD))

                    var magnitudes = [Float](repeating: 0, count: windowSize / 2)
                    vDSP_zvmags(&output, 1, &magnitudes, 1, vDSP_Length(windowSize / 2))

                    // パワーに変換（振幅の2乗）
                    var power = [Float](repeating: 0, count: windowSize / 2)
                    vDSP_vsq(magnitudes, 1, &power, 1, vDSP_Length(windowSize / 2))

                    // スペクトル重心 (Spectral Centroid)
                    var centroidNumerator: Float = 0
                    var centroidDenominator: Float = 0
                    let binFreq = Float(sampleRate) / Float(windowSize)

                    for bin in 0 ..< windowSize / 2 {
                        let freq = Float(bin) * binFreq
                        let mag = magnitudes[bin]
                        centroidNumerator += freq * mag
                        centroidDenominator += mag
                    }
                    let spectralCentroid = centroidDenominator > 0 ? centroidNumerator / centroidDenominator : 0

                    // 帯域別エネルギー
                    let speechLowBin = Int(300 / binFreq)
                    let speechHighBin = Int(4000 / binFreq)

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
                        highFrequencyEnergy: highEnergy,
                        spectralCentroid: spectralCentroid,
                        zeroCrossingRate: zcr
                    ))
                }
            }
        }

        return features
    }

    /// 抽出された特徴量からセグメント（演奏・会話・無音）を判定します
    func calculateSegments(from features: [AudioFeaturePoint]) -> [AudioSegment] {
        guard !features.isEmpty else { return [] }

        // 閾値をより敏感に調整 (RMS正規化後の信号を想定)
        let silenceThreshold: Float = 0.0008 // 約 -62dB
        let performanceThreshold: Float = 0.015 // 約 -36dB

        var rawSegments: [AudioSegment] = []
        var currentType: SegmentType = .silence
        var startTime: TimeInterval = features[0].time

        for feature in features {
            let type: SegmentType

            if feature.rms < silenceThreshold {
                type = .silence
            } else if feature.rms > performanceThreshold {
                type = .performance
            } else {
                // 中間音量域の判定ロジック
                let speechRatio = feature.lowFrequencyEnergy / (feature.lowFrequencyEnergy + feature.highFrequencyEnergy + 0.000001)

                // 会話の判定条件を少し緩める
                if speechRatio > 0.6 && feature.spectralCentroid < 3500 {
                    type = .conversation
                } else if feature.spectralCentroid > 4500 || feature.zeroCrossingRate > 0.25 {
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

        if let lastFeature = features.last {
            rawSegments.append(AudioSegment(startTime: startTime, endTime: lastFeature.time, type: currentType))
        }

        return smoothSegments(rawSegments)
    }

    private func smoothSegments(_ segments: [AudioSegment]) -> [AudioSegment] {
        guard segments.count > 1 else { return segments }

        // Phase 12の要件: 5秒以下のセグメントは原則として許容しない（極端な細分化を防ぐ）
        // ただし、無音区間などは短くても良い場合があるため、調整が必要
        let minDuration: TimeInterval = 3.0

        var smoothed: [AudioSegment] = []
        var current = segments[0]

        for i in 1 ..< segments.count {
            let next = segments[i]

            // 短いセグメントを前後の長いセグメントに統合する
            if next.duration < minDuration {
                // 次が短すぎる場合は現在に統合
                current = AudioSegment(startTime: current.startTime, endTime: next.endTime, type: current.type)
            } else if current.duration < minDuration {
                // 現在が短すぎる場合は次に統合
                current = AudioSegment(startTime: current.startTime, endTime: next.endTime, type: next.type)
            } else if current.type == next.type {
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
