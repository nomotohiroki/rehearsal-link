import AVFoundation
@testable import RehearsalLink
import XCTest

final class AudioProcessorTests: XCTestCase {
    var audioProcessor: AudioProcessor!

    override func setUp() {
        super.setUp()
        audioProcessor = AudioProcessor()
    }

    func testNormalizePeak() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let frameCount: AVAudioFrameCount = 1024
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = frameCount

        let data = try XCTUnwrap(buffer.floatChannelData?[0])
        for i in 0 ..< Int(frameCount) {
            data[i] = sin(Float(i) * 0.1) * 0.1
        }

        let targetDB: Float = -3.0
        let targetAmplitude = pow(10.0, targetDB / 20.0)

        guard let normalizedBuffer = audioProcessor.normalize(buffer: buffer, targetLevelDecibels: targetDB) else {
            XCTFail("Normalization failed")
            return
        }

        let normalizedData = try XCTUnwrap(normalizedBuffer.floatChannelData?[0])
        var maxAmplitude: Float = 0
        for i in 0 ..< Int(frameCount) {
            maxAmplitude = max(maxAmplitude, abs(normalizedData[i]))
        }

        XCTAssertEqual(maxAmplitude, targetAmplitude, accuracy: 0.001)
    }

    func testNormalizeRMS() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let frameCount: AVAudioFrameCount = 4096
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = frameCount

        // 非常に小さい音量のホワイトノイズのようなデータ
        let data = try XCTUnwrap(buffer.floatChannelData?[0])
        for i in 0 ..< Int(frameCount) {
            data[i] = (Float.random(in: -1 ... 1)) * 0.001
        }

        let targetDB: Float = -20.0
        let targetRMS = pow(10.0, targetDB / 20.0)

        guard let normalizedBuffer = audioProcessor.normalizeRMS(buffer: buffer, targetRMSDecibels: targetDB) else {
            XCTFail("Normalization failed")
            return
        }

        let normalizedData = try XCTUnwrap(normalizedBuffer.floatChannelData?[0])
        var sumSquares: Float = 0
        for i in 0 ..< Int(frameCount) {
            sumSquares += normalizedData[i] * normalizedData[i]
        }
        let resultRMS = sqrt(sumSquares / Float(frameCount))

        // RMSが目標値に近いことを確認
        XCTAssertEqual(resultRMS, targetRMS, accuracy: 0.01)
    }

    func testNormalizeSilence() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let frameCount: AVAudioFrameCount = 1024
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            XCTFail("Failed to create buffer")
            return
        }
        buffer.frameLength = frameCount

        let normalizedBuffer = audioProcessor.normalizeRMS(buffer: buffer)
        XCTAssertNotNil(normalizedBuffer)

        let normalizedData = try XCTUnwrap(normalizedBuffer?.floatChannelData?[0])
        for i in 0 ..< Int(frameCount) {
            XCTAssertEqual(normalizedData[i], 0)
        }
    }
}
