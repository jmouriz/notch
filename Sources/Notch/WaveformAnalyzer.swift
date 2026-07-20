import AVFoundation
import CoreGraphics
import Foundation

actor WaveformAnalyzer {
    func analyze(
        url: URL,
        targetSampleCount: Int = 720
    ) throws -> [CGFloat] {
        let file = try AVAudioFile(forReading: url)
        let format = file.processingFormat
        let totalFrames = max(1, file.length)
        let framesPerSample = max(
            AVAudioFramePosition(1),
            totalFrames / AVAudioFramePosition(targetSampleCount)
        )
        let capacity = AVAudioFrameCount(
            min(framesPerSample, AVAudioFramePosition(UInt32.max))
        )
        guard let buffer = AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: capacity
        ) else {
            return []
        }

        var peaks: [Float] = []
        while file.framePosition < file.length {
            buffer.frameLength = 0
            try file.read(into: buffer, frameCount: capacity)
            guard buffer.frameLength > 0 else { break }
            peaks.append(peakAmplitude(in: buffer))
        }

        guard let maximum = peaks.max(), maximum > 0 else {
            return Array(repeating: 0.06, count: max(2, peaks.count))
        }

        return peaks.map { peak in
            CGFloat(max(0.04, min(1, peak / maximum)))
        }
    }

    private func peakAmplitude(in buffer: AVAudioPCMBuffer) -> Float {
        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)
        guard frameCount > 0, channelCount > 0 else { return 0 }

        if let channels = buffer.floatChannelData {
            var peak: Float = 0
            for channel in 0..<channelCount {
                for frame in 0..<frameCount {
                    peak = max(peak, abs(channels[channel][frame]))
                }
            }
            return peak
        }

        if let channels = buffer.int16ChannelData {
            var peak: Int32 = 0
            for channel in 0..<channelCount {
                for frame in 0..<frameCount {
                    peak = max(
                        peak,
                        abs(Int32(channels[channel][frame]))
                    )
                }
            }
            return Float(peak) / Float(Int16.max)
        }

        return 0
    }
}
