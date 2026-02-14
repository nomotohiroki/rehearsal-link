import Accelerate
import AVFoundation

/// 音声データに対する各種処理を担当するクラス
struct AudioProcessor: Sendable {
    /// オーディオデータのピーク正規化を行います。
    func normalize(buffer: AVAudioPCMBuffer, targetLevelDecibels: Float = -3.0) -> AVAudioPCMBuffer? {
        guard let floatData = buffer.floatChannelData else { return nil }

        let frameLength = vDSP_Length(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        var maxAmplitude: Float = 0
        for channel in 0 ..< channelCount {
            var channelMax: Float = 0
            vDSP_maxmgv(floatData[channel], 1, &channelMax, frameLength)
            maxAmplitude = max(maxAmplitude, channelMax)
        }

        if maxAmplitude < 0.000001 { return buffer }

        let targetAmplitude = pow(10.0, targetLevelDecibels / 20.0)
        let gain = targetAmplitude / maxAmplitude

        return applyGain(buffer: buffer, gain: gain)
    }

    /// オーディオデータのRMS正規化を行います。
    /// ピーク正規化よりも強力に音量を引き上げることができます。
    /// - Parameters:
    ///   - buffer: 正規化対象のPCMバッファ
    ///   - targetRMSDecibels: 目標とするRMSレベル（デフォルトは -20.0 dBFS）
    /// - Returns: 正規化された新しいPCMバッファ
    func normalizeRMS(buffer: AVAudioPCMBuffer, targetRMSDecibels: Float = -20.0) -> AVAudioPCMBuffer? {
        guard let floatData = buffer.floatChannelData else { return nil }

        let frameLength = vDSP_Length(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // 1. 全チャンネルの平均RMSを求める
        var totalRMS: Float = 0
        for channel in 0 ..< channelCount {
            var channelRMS: Float = 0
            vDSP_rmsqv(floatData[channel], 1, &channelRMS, frameLength)
            totalRMS += channelRMS
        }
        let averageRMS = totalRMS / Float(channelCount)

        // 極端に無音に近い場合は処理しない
        if averageRMS < 0.000001 { return buffer }

        // 2. 目標RMSからゲインを計算
        let targetRMS = pow(10.0, targetRMSDecibels / 20.0)
        var gain = targetRMS / averageRMS

        // 過度な増幅を防ぐため、最大ゲインを制限（例: 60dB = 1000倍）
        gain = min(gain, 1000.0)

        print("AudioProcessor: RMS Normalization - Current RMS: \(20 * log10(averageRMS))dB, Target: \(targetRMSDecibels)dB, Gain: \(20 * log10(gain))dB")

        return applyGain(buffer: buffer, gain: gain)
    }

    func applyGain(buffer: AVAudioPCMBuffer, gain: Float) -> AVAudioPCMBuffer? {
        guard let floatData = buffer.floatChannelData,
              let outputBuffer = AVAudioPCMBuffer(pcmFormat: buffer.format, frameCapacity: buffer.frameLength) else {
            return nil
        }
        outputBuffer.frameLength = buffer.frameLength
        guard let outputFloatData = outputBuffer.floatChannelData else { return nil }

        let frameLength = vDSP_Length(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        for channel in 0 ..< channelCount {
            vDSP_vsmul(floatData[channel], 1, [gain], outputFloatData[channel], 1, frameLength)
        }

        return outputBuffer
    }
}
