import Foundation
import Testing
@testable import Notch

@MainActor
@Test func preferencesPersistFoldersFormatsAndNaming() throws {
    let suiteName = "NotchTests.Preferences.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let root = FileManager.default.temporaryDirectory
        .appendingPathComponent("notch-preferences-\(UUID().uuidString)", isDirectory: true)
    let preferences = AppPreferences(userDefaults: defaults)
    preferences.cacheDirectoryURL = root.appendingPathComponent("Cache", isDirectory: true)
    preferences.libraryDirectoryURL = root.appendingPathComponent("Library", isDirectory: true)
    preferences.exportDirectoryURL = root.appendingPathComponent("Exports", isDirectory: true)
    preferences.outputFormat = .mp3
    preferences.namingConvention = .clipParenthesizedBase

    let restored = AppPreferences(userDefaults: defaults)
    #expect(restored.cacheDirectoryURL.lastPathComponent == "Cache")
    #expect(restored.libraryDirectoryURL.lastPathComponent == "Library")
    #expect(restored.exportDirectoryURL.lastPathComponent == "Exports")
    #expect(restored.outputFormat == .mp3)
    #expect(restored.namingConvention == .clipParenthesizedBase)
}

@MainActor
@Test func preferencesClearTheSelectedCacheOnly() throws {
    let suiteName = "NotchTests.Cache.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let cache = FileManager.default.temporaryDirectory
        .appendingPathComponent("notch-cache-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(
        at: cache.appendingPathComponent("video", isDirectory: true),
        withIntermediateDirectories: true
    )
    try Data(repeating: 1, count: 1_024).write(
        to: cache.appendingPathComponent("video/source.m4a")
    )
    defer { try? FileManager.default.removeItem(at: cache) }

    let preferences = AppPreferences(userDefaults: defaults)
    preferences.cacheDirectoryURL = cache
    #expect(preferences.cacheSize() == 1_024)

    try preferences.clearCache()

    #expect(preferences.cacheSize() == 0)
    #expect(FileManager.default.fileExists(atPath: cache.path))
}

@MainActor
@Test func outputNamesFollowTheSelectedConventionAndFormat() throws {
    let suiteName = "NotchTests.Naming.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = EditorStore(userDefaults: defaults)
    store.projectName = "Mis historias"
    let region = ClipRegion(start: 0, end: 10, name: "Don Heraclio")

    store.preferences.outputFormat = .wav
    store.preferences.namingConvention = .baseDashClip
    #expect(store.outputName(for: region, index: 0) == "Mis historias - Don Heraclio.wav")

    store.preferences.namingConvention = .clipParenthesizedBase
    #expect(store.outputName(for: region, index: 0) == "Don Heraclio (Mis historias).wav")

    store.preferences.namingConvention = .baseFolderClip
    #expect(store.outputName(for: region, index: 0) == "Mis historias/Don Heraclio.wav")
}
