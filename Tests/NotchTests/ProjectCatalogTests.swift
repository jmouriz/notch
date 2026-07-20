import Foundation
import Testing
@testable import Notch

@MainActor
@Test func projectCatalogPersistsConservedProjects() throws {
    let suiteName = "NotchTests.ProjectCatalog.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let projectURL = FileManager.default.temporaryDirectory
        .appendingPathComponent("catalog-\(UUID().uuidString).notch")
    try Data("{}".utf8).write(to: projectURL)
    defer { try? FileManager.default.removeItem(at: projectURL) }

    let entry = ProjectCatalogEntry(
        projectPath: projectURL.path,
        name: "Proyecto conservado",
        sourceDescription: "https://youtu.be/example",
        lastOpened: Date(),
        isConserved: false
    )
    defaults.set(
        try JSONEncoder().encode([entry]),
        forKey: "NotchProjectCatalog.v1"
    )

    let store = EditorStore(userDefaults: defaults)
    #expect(store.recentProjects.count == 1)
    #expect(store.conservedProjects.isEmpty)

    store.toggleConserved(entry)
    #expect(store.conservedProjects.count == 1)

    let restoredStore = EditorStore(userDefaults: defaults)
    #expect(restoredStore.conservedProjects.first?.name == "Proyecto conservado")

    if let restored = restoredStore.conservedProjects.first {
        restoredStore.removeCatalogEntry(restored)
    }
    #expect(restoredStore.recentProjects.isEmpty)
}
