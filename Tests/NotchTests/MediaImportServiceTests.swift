import AVFoundation
import Foundation
import Testing
@testable import Notch

@Test func importsALocalAudioFileWithItsRealDuration() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notch-local-import-\(UUID().uuidString).wav")
    defer { try? FileManager.default.removeItem(at: url) }

    let format = try #require(
        AVAudioFormat(
            standardFormatWithSampleRate: 44_100,
            channels: 1
        )
    )
    var file: AVAudioFile? = try AVAudioFile(
        forWriting: url,
        settings: format.settings
    )
    let buffer = try #require(
        AVAudioPCMBuffer(
            pcmFormat: format,
            frameCapacity: 44_100
        )
    )
    buffer.frameLength = 44_100
    try file?.write(from: buffer)
    file = nil

    let imported = try await MediaImportService().importLocalFile(url)

    #expect(imported.localURL == url)
    #expect(imported.title.hasPrefix("notch-local-import-"))
    #expect(abs(imported.duration - 1) < 0.02)
    #expect(!imported.wasCached)

    let samples = try await WaveformAnalyzer().analyze(
        url: url,
        targetSampleCount: 100
    )
    #expect(samples.count >= 90)
    #expect(samples.allSatisfy { $0 >= 0.04 && $0 <= 1 })
}

@Test func extractsYouTubeIdentifiersForCacheLookup() throws {
    let expected = "tm-clFpSLb0"
    let urls = [
        "https://www.youtube.com/watch?v=tm-clFpSLb0",
        "https://youtu.be/tm-clFpSLb0?si=share",
        "https://www.youtube.com/shorts/tm-clFpSLb0",
        "https://music.youtube.com/watch?v=tm-clFpSLb0"
    ]

    for value in urls {
        let url = try #require(URL(string: value))
        #expect(MediaImportService.youtubeIdentifier(from: url) == expected)
    }

    let unrelated = try #require(URL(string: "https://example.com/watch?v=tm-clFpSLb0"))
    #expect(MediaImportService.youtubeIdentifier(from: unrelated) == nil)
}
