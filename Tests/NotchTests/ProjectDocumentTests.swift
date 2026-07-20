import Foundation
import Testing
@testable import Notch

@Test func projectDocumentRoundTripsAllEditingMetadata() throws {
    let url = FileManager.default.temporaryDirectory
        .appendingPathComponent("project-\(UUID().uuidString).notch")
    defer { try? FileManager.default.removeItem(at: url) }

    let regions = [
        ClipRegion(
            start: 12.345,
            end: 67.890,
            name: "Primera parte",
            isEnabled: true,
            colorIndex: 2
        ),
        ClipRegion(
            start: 80,
            end: 95,
            name: "Descartada",
            isEnabled: false,
            colorIndex: 3
        )
    ]
    let document = NotchProjectDocument(
        name: "Historias favoritas",
        source: ProjectSourceReference(
            kind: .remote,
            location: "https://www.youtube.com/watch?v=tm-clFpSLb0"
        ),
        regions: regions,
        exportDirectoryPath: "/Users/juanma/Music/Recortes",
        playhead: 34.5,
        zoom: 2.75
    )

    try document.write(to: url)
    let restored = try NotchProjectDocument.load(from: url)

    #expect(restored == document)
    #expect(restored.regions.map(\.name) == ["Primera parte", "Descartada"])
    #expect(restored.exportDirectoryPath == "/Users/juanma/Music/Recortes")
}
