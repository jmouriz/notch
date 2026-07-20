import AppKit
import Foundation
import Observation

enum AudioOutputFormat: String, CaseIterable, Codable, Identifiable, Sendable {
    case m4a
    case mp3
    case wav

    var id: String { rawValue }
    var displayName: String { rawValue.uppercased() }
    var fileExtension: String { rawValue }

    var qualityDescription: String {
        switch self {
        case .m4a:
            return L10n.string("quality.m4a")
        case .mp3:
            return L10n.string("quality.mp3")
        case .wav:
            return L10n.string("quality.wav")
        }
    }
}

enum ExportNamingConvention: String, CaseIterable, Codable, Identifiable, Sendable {
    case baseDashClip
    case clipParenthesizedBase
    case baseFolderClip

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .baseDashClip:
            return L10n.string("naming.base_dash_clip")
        case .clipParenthesizedBase:
            return L10n.string("naming.clip_parenthesized_base")
        case .baseFolderClip:
            return L10n.string("naming.base_folder_clip")
        }
    }

    var example: String {
        switch self {
        case .baseDashClip:
            return L10n.string("naming.example.base_dash_clip")
        case .clipParenthesizedBase:
            return L10n.string("naming.example.clip_parenthesized_base")
        case .baseFolderClip:
            return L10n.string("naming.example.base_folder_clip")
        }
    }
}

@MainActor
@Observable
final class AppPreferences {
    var cacheDirectoryURL: URL {
        didSet { persist(cacheDirectoryURL, key: Keys.cacheDirectory) }
    }
    var libraryDirectoryURL: URL {
        didSet { persist(libraryDirectoryURL, key: Keys.libraryDirectory) }
    }
    var exportDirectoryURL: URL {
        didSet { persist(exportDirectoryURL, key: Keys.exportDirectory) }
    }
    var outputFormat: AudioOutputFormat {
        didSet { userDefaults.set(outputFormat.rawValue, forKey: Keys.outputFormat) }
    }
    var namingConvention: ExportNamingConvention {
        didSet { userDefaults.set(namingConvention.rawValue, forKey: Keys.namingConvention) }
    }
    var language: AppLanguage {
        didSet {
            userDefaults.set(language.rawValue, forKey: L10n.languageDefaultsKey)
        }
    }

    @ObservationIgnored private let userDefaults: UserDefaults

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults

        let home = FileManager.default.homeDirectoryForCurrentUser
        let defaultCache = home
            .appendingPathComponent("Library/Caches/ar.tecnologica.notch/Media", isDirectory: true)
        let defaultLibrary = home
            .appendingPathComponent("Documents/Notch", isDirectory: true)
        let defaultExport = home
            .appendingPathComponent("Music/Notch", isDirectory: true)

        cacheDirectoryURL = Self.storedURL(
            key: Keys.cacheDirectory,
            defaults: userDefaults
        ) ?? defaultCache
        libraryDirectoryURL = Self.storedURL(
            key: Keys.libraryDirectory,
            defaults: userDefaults
        ) ?? defaultLibrary
        exportDirectoryURL = Self.storedURL(
            key: Keys.exportDirectory,
            defaults: userDefaults
        ) ?? defaultExport
        outputFormat = AudioOutputFormat(
            rawValue: userDefaults.string(forKey: Keys.outputFormat) ?? ""
        ) ?? .m4a
        namingConvention = ExportNamingConvention(
            rawValue: userDefaults.string(forKey: Keys.namingConvention) ?? ""
        ) ?? .baseDashClip
        language = AppLanguage(
            rawValue: userDefaults.string(forKey: L10n.languageDefaultsKey) ?? ""
        ) ?? .system
    }

    func chooseCacheDirectory() {
        if let url = chooseDirectory(
            title: L10n.string("settings.cache_folder", language: language),
            current: cacheDirectoryURL
        ) {
            cacheDirectoryURL = url
        }
    }

    func chooseLibraryDirectory() {
        if let url = chooseDirectory(
            title: L10n.string("settings.library_folder", language: language),
            current: libraryDirectoryURL
        ) {
            libraryDirectoryURL = url
        }
    }

    func chooseExportDirectory() {
        if let url = chooseDirectory(
            title: L10n.string("settings.export_folder", language: language),
            current: exportDirectoryURL
        ) {
            exportDirectoryURL = url
        }
    }

    func openDirectory(_ url: URL) {
        try? FileManager.default.createDirectory(
            at: url,
            withIntermediateDirectories: true
        )
        NSWorkspace.shared.open(url)
    }

    func clearCache() throws {
        guard FileManager.default.fileExists(atPath: cacheDirectoryURL.path) else {
            return
        }
        let contents = try FileManager.default.contentsOfDirectory(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: nil
        )
        for url in contents {
            try FileManager.default.removeItem(at: url)
        }
    }

    func cacheSize() -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: cacheDirectoryURL,
            includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var total: Int64 = 0
        for case let url as URL in enumerator {
            guard let values = try? url.resourceValues(
                forKeys: [.fileSizeKey, .isRegularFileKey]
            ), values.isRegularFile == true else {
                continue
            }
            total += Int64(values.fileSize ?? 0)
        }
        return total
    }

    private func chooseDirectory(title: String, current: URL) -> URL? {
        let panel = NSOpenPanel()
        panel.title = title
        panel.prompt = L10n.string("settings.select", language: language)
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = current
        return panel.runModal() == .OK ? panel.url : nil
    }

    private func persist(_ url: URL, key: String) {
        userDefaults.set(url.path(percentEncoded: false), forKey: key)
    }

    private static func storedURL(
        key: String,
        defaults: UserDefaults
    ) -> URL? {
        guard let path = defaults.string(forKey: key), !path.isEmpty else {
            return nil
        }
        return URL(fileURLWithPath: path, isDirectory: true)
    }

    private enum Keys {
        static let cacheDirectory = "NotchPreferences.cacheDirectory"
        static let libraryDirectory = "NotchPreferences.libraryDirectory"
        static let exportDirectory = "NotchPreferences.exportDirectory"
        static let outputFormat = "NotchPreferences.outputFormat"
        static let namingConvention = "NotchPreferences.namingConvention"
    }
}
