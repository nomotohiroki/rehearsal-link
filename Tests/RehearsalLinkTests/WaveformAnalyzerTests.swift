import AVFoundation
@testable import RehearsalLink
import XCTest

final class WaveformAnalyzerTests: XCTestCase {
    var analyzer: WaveformAnalyzer!

    override func setUp() {
        super.setUp()
        analyzer = WaveformAnalyzer()
    }

    func testGenerateWaveformSamplesWithEmptyBuffer() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 2))
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 100))
        buffer.frameLength = 0

        let samples = analyzer.generateWaveformSamples(from: buffer, targetSampleCount: 10)
        XCTAssertTrue(samples.isEmpty)
    }

    func testGenerateWaveformSamples() throws {
        let format = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1))
        let frameCount: AVAudioFrameCount = 1000
        let buffer = try XCTUnwrap(AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount))
        buffer.frameLength = frameCount

        // Fill buffer with sine wave
        for i in 0 ..< Int(frameCount) {
            buffer.floatChannelData?[0][i] = sin(Float(i) * 0.1)
        }

        let targetCount = 100
        let samples = analyzer.generateWaveformSamples(from: buffer, targetSampleCount: targetCount)

        XCTAssertEqual(samples.count, targetCount)
        for sample in samples {
            XCTAssertTrue(sample.min >= -1.0)
            XCTAssertTrue(sample.max <= 1.0)
            XCTAssertTrue(sample.min <= sample.max)
        }
    }

    func testCalculateSegments() {
        let features: [AudioFeaturePoint] = [
            AudioFeaturePoint(time: 0.0, rms: 0.0001, lowFrequencyEnergy: 0, highFrequencyEnergy: 0), // Silence
            AudioFeaturePoint(time: 1.0, rms: 0.0001, lowFrequencyEnergy: 0, highFrequencyEnergy: 0),
            AudioFeaturePoint(time: 2.0, rms: 0.1, lowFrequencyEnergy: 1, highFrequencyEnergy: 10), // Performance
            AudioFeaturePoint(time: 3.0, rms: 0.1, lowFrequencyEnergy: 1, highFrequencyEnergy: 10),
            AudioFeaturePoint(time: 4.0, rms: 0.01, lowFrequencyEnergy: 10, highFrequencyEnergy: 1), // Conversation
            AudioFeaturePoint(time: 5.0, rms: 0.01, lowFrequencyEnergy: 10, highFrequencyEnergy: 1),
            AudioFeaturePoint(time: 6.0, rms: 0.0001, lowFrequencyEnergy: 0, highFrequencyEnergy: 0) // Silence
        ]

        let segments = analyzer.calculateSegments(from: features)

        XCTAssertFalse(segments.isEmpty)
        // Since smoothing is applied, exact count might vary but should be reasonable
        XCTAssertTrue(segments.count >= 1)
    }
}
