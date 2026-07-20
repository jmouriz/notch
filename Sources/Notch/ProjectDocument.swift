import Foundation
import UniformTypeIdentifiers

extension UTType {
    static let notchProject = UTType(
        exportedAs: "ar.tecnologica.notch.project",
        conformingTo: .json
    )
}

enum ProjectSourceKind: String, Codable, Sendable {
    case local
    case remote
}

struct ProjectSourceReference: Codable, Equatable, Sendable {
    let kind: ProjectSourceKind
    let location: String
}

struct NotchProjectDocument: Codable, Equatable, Sendable {
    static let currentVersion = 1

    let version: Int
    var name: String
    var source: ProjectSourceReference
    var regions: [ClipRegion]
    var exportDirectoryPath: String?
    var playhead: TimeInterval
    var zoom: Double

    init(
        name: String,
        source: ProjectSourceReference,
        regions: [ClipRegion],
        exportDirectoryPath: String?,
        playhead: TimeInterval,
        zoom: Double
    ) {
        version = Self.currentVersion
        self.name = name
        self.source = source
        self.regions = regions
        self.exportDirectoryPath = exportDirectoryPath
        self.playhead = playhead
        self.zoom = zoom
    }

    static func load(from url: URL) throws -> NotchProjectDocument {
        let document = try JSONDecoder().decode(
            NotchProjectDocument.self,
            from: Data(contentsOf: url)
        )
        guard document.version <= currentVersion else {
            throw ProjectDocumentError.newerVersion
        }
        return document
    }

    func write(to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        try encoder.encode(self).write(to: url, options: .atomic)
    }
}

enum ProjectDocumentError: LocalizedError {
    case noSource
    case invalidSource
    case newerVersion

    var errorDescription: String? {
        switch self {
        case .noSource:
            return L10n.string("error.project_no_source")
        case .invalidSource:
            return L10n.string("error.project_invalid_source")
        case .newerVersion:
            return L10n.string("error.project_newer_version")
        }
    }
}
