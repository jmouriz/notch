import Testing
import AVFoundation
import Foundation
@testable import Notch

@MainActor
@Test func importingANewSourceResetsTheEditingState() {
    let store = EditorStore()
    store.playhead = 78.42
    store.isPlaying = true
    store.zoom = 4
    let region = ClipRegion(start: 10, end: 20, name: "Anterior")
    store.regions = [region]
    store.selectedRegionID = region.id

    store.prepareForNewSource()

    #expect(store.playhead == 0)
    #expect(!store.isPlaying)
    #expect(store.zoom == 1)
    #expect(store.regions.isEmpty)
    #expect(store.selectedRegionID == nil)
}

@MainActor
@Test func playbackSupportsSeekPlayAndPause() async throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("notch-playback-\(UUID().uuidString).wav")
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
            frameCapacity: 88_200
        )
    )
    buffer.frameLength = 88_200
    try file?.write(from: buffer)
    file = nil

    let imported = try await MediaImportService().importLocalFile(url)
    let store = EditorStore()
    store.apply(imported)
    store.seek(to: 0.5)

    #expect(abs(store.playhead - 0.5) < 0.001)

    store.togglePlayback()

    #expect(store.isPlaying)

    store.togglePlayback()

    #expect(!store.isPlaying)
    store.resetProject()
}

@MainActor
@Test func manualRegionBoundsImmediatelyUpdateTheModel() {
    let store = EditorStore()
    store.source = AudioSource(
        id: UUID(),
        title: "Prueba",
        subtitle: "",
        duration: 1_200,
        origin: .local,
        localURL: nil
    )
    let region = ClipRegion(start: 100, end: 200, name: "Manual")
    store.regions = [region]

    store.setRegionBounds(id: region.id, start: 380.826)
    store.setRegionBounds(id: region.id, end: 559.260)

    let updated = store.regions[0]
    #expect(abs(updated.start - 380.826) < 0.001)
    #expect(abs(updated.end - 559.260) < 0.001)
    #expect(store.selectedRegionID == region.id)
}
