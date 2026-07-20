import Foundation

enum LibraryDestination: String, CaseIterable, Hashable, Sendable {
    case current
    case recent
    case conserved
}

struct ProjectCatalogEntry: Codable, Equatable, Identifiable, Sendable {
    var id: String { projectPath }

    let projectPath: String
    var name: String
    var sourceDescription: String
    var lastOpened: Date
    var isConserved: Bool

    var projectURL: URL {
        URL(fileURLWithPath: projectPath)
    }
}
