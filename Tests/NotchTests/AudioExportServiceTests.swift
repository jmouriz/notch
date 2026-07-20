import AVFoundation
import Foundation
import Testing
@testable import Notch

@Test func exportsARegionAsM4A() async throws {
    let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("notch-export-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: directory,
        withIntermediateDirectories: true
    )
    defer { try? FileManager.default.removeItem(at: directory) }

    let sourceURL = directory.appendingPathComponent("source.wav")
    let format = try #require(
        AVAudioFormat(standardFormatWithSampleRate: 44_100, channels: 1)
    )
    var file: AVAudioFile? = try AVAudioFile(
        forWriting: sourceURL,
        settings: format.settings
    )
    let buffer = try #require(
        AVAudioPCMBuffer(pcmFormat: format, frameCapacity: 88_200)
    )
    buffer.frameLength = 88_200
    try file?.write(from: buffer)
    file = nil

    for format in AudioOutputFormat.allCases {
        let urls = try await AudioExportService().export(
            sourceURL: sourceURL,
            jobs: [
                AudioExportJob(
                    region: ClipRegion(start: 0.25, end: 1.25, name: "Prueba"),
                    relativePath: "Mi colección/Prueba"
                )
            ],
            destinationDirectory: directory,
            format: format
        )

        let outputURL = try #require(urls.first)
        #expect(outputURL.pathExtension == format.fileExtension)
        #expect(FileManager.default.fileExists(atPath: outputURL.path))
        let duration = try await AVURLAsset(url: outputURL).load(.duration).seconds
        #expect(abs(duration - 1) < 0.10)
    }
}
