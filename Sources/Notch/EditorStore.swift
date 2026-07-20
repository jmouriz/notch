import AppKit
import AVFoundation
import Foundation
import Observation

@MainActor
@Observable
final class EditorStore {
    var librarySelection: LibraryDestination = .current
    var projectCatalog: [ProjectCatalogEntry] = []
    var sourceURL = ""
    var projectName = ""
    var source = AudioSource.empty
    var hasLoadedSource = false
    var regions: [ClipRegion] = []
    var selectedRegionID: ClipRegion.ID?
    var playhead: TimeInterval = 0
    var isPlaying = false
    var isImporting = false
    var importProgress: Double?
    var isExporting = false
    var exportProgress: Double = 0
    var isAnalyzingWaveform = false
    var waveformSamples: [CGFloat] = []
    var statusMessage = ""
    var zoom: Double = 1
    var exportDirectoryURL: URL?
    var currentProjectURL: URL?

    @ObservationIgnored private let importService = MediaImportService()
    @ObservationIgnored private let exportService = AudioExportService()
    @ObservationIgnored private let waveformAnalyzer = WaveformAnalyzer()
    @ObservationIgnored private let userDefaults: UserDefaults
    @ObservationIgnored let preferences: AppPreferences
    @ObservationIgnored private var player: AVPlayer?
    @ObservationIgnored private var timeObserver: Any?
    @ObservationIgnored private var playbackEndObserver: NSObjectProtocol?
    @ObservationIgnored private var previewEnd: TimeInterval?

    var selectedRegion: ClipRegion? {
        guard let selectedRegionID else { return nil }
        return regions.first { $0.id == selectedRegionID }
    }

    init(userDefaults: UserDefaults = .standard) {
        self.userDefaults = userDefaults
        preferences = AppPreferences(userDefaults: userDefaults)
        projectCatalog = Self.loadProjectCatalog(from: userDefaults)
        projectName = L10n.string("default.project_name", language: preferences.language)
        statusMessage = L10n.string("status.ready", language: preferences.language)
        selectedRegionID = regions.first?.id
    }

    func t(_ key: String, _ arguments: CVarArg...) -> String {
        let format = L10n.string(key, language: preferences.language)
        return String(
            format: format,
            locale: preferences.language.locale,
            arguments: arguments
        )
    }

    func languageDidChange() {
        let defaultNames = AppLanguage.allCases.map {
            L10n.string("default.project_name", language: $0)
        }
        if !hasLoadedSource && defaultNames.contains(projectName) {
            projectName = t("default.project_name")
        }
        statusMessage = t("status.ready")
    }

    var recentProjects: [ProjectCatalogEntry] {
        projectCatalog.sorted { $0.lastOpened > $1.lastOpened }
    }

    var conservedProjects: [ProjectCatalogEntry] {
        recentProjects.filter(\.isConserved)
    }

    func resetProject() {
        librarySelection = .current
        sourceURL = ""
        projectName = t("default.project_name")
        source = .empty
        hasLoadedSource = false
        regions = []
        selectedRegionID = nil
        playhead = 0
        isPlaying = false
        isImporting = false
        importProgress = nil
        isExporting = false
        exportProgress = 0
        isAnalyzingWaveform = false
        waveformSamples = []
        zoom = 1
        exportDirectoryURL = nil
        currentProjectURL = nil
        statusMessage = t("status.new_project")
        releasePlayer()
    }

    func importRemoteSource() {
        guard !isImporting, !isExporting else { return }
        librarySelection = .current
        let trimmed = sourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), url.scheme != nil else {
            statusMessage = t("status.invalid_url")
            NSSound.beep()
            return
        }

        isImporting = true
        importProgress = 0
        statusMessage = t("status.checking_source")
        Task {
            do {
                let imported = try await importService.importRemoteURL(
                    url,
                    cacheRoot: preferences.cacheDirectoryURL
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isImporting else { return }
                        self.importProgress = progress
                        if progress < 0.10 {
                            self.statusMessage = self.t("status.searching_cache")
                        } else if progress < 1 {
                            self.statusMessage = self.t("status.downloading", Int(progress * 100))
                        } else {
                            self.statusMessage = self.t("status.preparing_audio")
                        }
                    }
                }
                apply(imported)
                currentProjectURL = nil
                exportDirectoryURL = nil
                statusMessage = imported.wasCached
                    ? t("status.cached_audio")
                    : t("status.downloaded_audio")
            } catch {
                isImporting = false
                importProgress = nil
                statusMessage = error.localizedDescription
                NSSound.beep()
            }
        }
    }

    func chooseLocalFile() {
        guard !isImporting, !isExporting else { return }
        librarySelection = .current
        let panel = NSOpenPanel()
        panel.title = t("panel.select_media")
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.allowedContentTypes = [.audio, .movie, .mpeg4Movie]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        isImporting = true
        importProgress = nil
        statusMessage = t("status.reading_file")
        Task {
            do {
                let imported = try await importService.importLocalFile(url)
                apply(imported)
                currentProjectURL = nil
                exportDirectoryURL = nil
                statusMessage = t("status.file_ready")
            } catch {
                isImporting = false
                importProgress = nil
                statusMessage = error.localizedDescription
                NSSound.beep()
            }
        }
    }

    func togglePlayback() {
        guard let player else {
            statusMessage = t("status.load_source_first")
            return
        }

        previewEnd = nil
        if isPlaying {
            player.pause()
            isPlaying = false
            statusMessage = t("status.paused")
        } else {
            if playhead >= source.duration - 0.01 {
                seek(to: 0)
            }
            player.play()
            isPlaying = true
            statusMessage = t("status.playing")
        }
    }

    func seek(to time: TimeInterval) {
        let target = min(max(0, time), source.duration)
        playhead = target
        player?.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func addRegionAtPlayhead() {
        guard hasLoadedSource, source.duration > 0 else {
            statusMessage = t("status.load_source_first")
            return
        }
        let start = min(playhead, max(0, source.duration - 10))
        let end = min(source.duration, start + 30)
        addRegion(from: start, to: end)
    }

    func addRegion(from firstTime: TimeInterval, to secondTime: TimeInterval) {
        let start = min(max(0, min(firstTime, secondTime)), source.duration)
        let end = min(max(start + 0.01, max(firstTime, secondTime)), source.duration)
        guard end - start >= 0.01 else { return }

        let region = ClipRegion(
            start: start,
            end: end,
            name: t("default.clip_name", regions.count + 1),
            colorIndex: regions.count
        )
        regions.append(region)
        selectedRegionID = region.id
        seek(to: start)
        statusMessage = t(
            "status.region_created",
            Timecode.string(from: start),
            Timecode.string(from: end)
        )
    }

    func deleteRegion(_ id: ClipRegion.ID) {
        regions.removeAll { $0.id == id }
        selectedRegionID = regions.first?.id
        statusMessage = t("status.region_deleted")
    }

    func updateRegion(_ updated: ClipRegion) {
        guard let index = regions.firstIndex(where: { $0.id == updated.id }) else { return }
        var clamped = updated
        clamped.start = min(max(0, clamped.start), source.duration)
        clamped.end = min(max(clamped.start + 0.01, clamped.end), source.duration)
        regions[index] = clamped
    }

    func setRegionBounds(id: ClipRegion.ID, start: TimeInterval? = nil, end: TimeInterval? = nil) {
        guard var region = regions.first(where: { $0.id == id }) else { return }
        if let start { region.start = start }
        if let end { region.end = end }
        updateRegion(region)
        selectedRegionID = id
        if let updated = regions.first(where: { $0.id == id }) {
            statusMessage = t(
                "status.region_updated",
                updated.name,
                Timecode.string(from: updated.start),
                Timecode.string(from: updated.end)
            )
        }
    }

    func preview(_ region: ClipRegion) {
        guard let player else {
            statusMessage = t("status.no_preview_audio")
            return
        }
        selectedRegionID = region.id
        seek(to: region.start)
        previewEnd = region.end
        player.play()
        isPlaying = true
        statusMessage = t("status.previewing", region.name)
    }

    func previewSelectedRegion() {
        guard let selectedRegion else {
            togglePlayback()
            return
        }
        preview(selectedRegion)
    }

    func exportRegions() {
        guard !isExporting else { return }
        guard let sourceURL = source.localURL else {
            statusMessage = AudioExportError.missingAudio.localizedDescription
            NSSound.beep()
            return
        }

        let jobs = regions.enumerated().compactMap { index, region in
            region.isEnabled
                ? AudioExportJob(
                    region: region,
                    relativePath: outputRelativePath(
                        for: region,
                        index: index
                    )
                )
                : nil
        }
        guard !jobs.isEmpty else {
            statusMessage = t("status.no_enabled_regions")
            return
        }

        guard let directory = availableExportDirectory()
            ?? promptForExportDirectory() else {
            return
        }

        isExporting = true
        exportProgress = 0
        statusMessage = t("status.exporting")
        Task {
            do {
                let exportedURLs = try await exportService.export(
                    sourceURL: sourceURL,
                    jobs: jobs,
                    destinationDirectory: directory,
                    format: preferences.outputFormat
                ) { [weak self] progress in
                    Task { @MainActor [weak self] in
                        guard let self, self.isExporting else { return }
                        self.exportProgress = progress
                        self.statusMessage = self.t(
                            "status.exporting_percent",
                            Int(progress * 100)
                        )
                    }
                }
                isExporting = false
                exportProgress = 1
                statusMessage = exportedURLs.count == 1
                    ? t("status.exported_one")
                    : t("status.exported_many", exportedURLs.count)
                NSWorkspace.shared.activateFileViewerSelecting(exportedURLs)
            } catch {
                isExporting = false
                exportProgress = 0
                statusMessage = error.localizedDescription
                NSSound.beep()
            }
        }
    }

    func chooseExportDirectory() {
        guard !isExporting else { return }
        if let directory = promptForExportDirectory() {
            exportDirectoryURL = directory
            statusMessage = t(
                "status.destination",
                directory.path(percentEncoded: false)
            )
        }
    }

    func saveProject() {
        guard let currentProjectURL else {
            saveProjectAs()
            return
        }
        writeProject(to: currentProjectURL)
    }

    func saveProjectAs() {
        guard hasLoadedSource else {
            statusMessage = ProjectDocumentError.noSource.localizedDescription
            NSSound.beep()
            return
        }

        let panel = NSSavePanel()
        panel.title = t("panel.save_project")
        panel.prompt = t("panel.save")
        panel.allowedContentTypes = [.notchProject]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = "\(safeProjectFilename()).notch"
        panel.directoryURL = currentProjectURL?.deletingLastPathComponent()
            ?? preferences.libraryDirectoryURL
        guard panel.runModal() == .OK, let url = panel.url else { return }
        writeProject(to: url)
    }

    func openProject() {
        guard !isImporting, !isExporting else { return }

        let panel = NSOpenPanel()
        panel.title = t("panel.open_project")
        panel.prompt = t("panel.open")
        panel.allowedContentTypes = [.notchProject, .json]
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.directoryURL = preferences.libraryDirectoryURL
        guard panel.runModal() == .OK, let projectURL = panel.url else { return }
        openProject(at: projectURL)
    }

    func openProject(at projectURL: URL) {
        guard !isImporting, !isExporting else { return }
        librarySelection = .current
        do {
            let document = try NotchProjectDocument.load(from: projectURL)
            load(document, projectURL: projectURL)
        } catch {
            statusMessage = error.localizedDescription
            NSSound.beep()
        }
    }

    private func load(
        _ document: NotchProjectDocument,
        projectURL: URL
    ) {
        isImporting = true
        importProgress = document.source.kind == .remote ? 0 : nil
        statusMessage = t("status.opening_project")

        Task {
            do {
                let imported: ImportedMedia
                switch document.source.kind {
                case .local:
                    let sourceURL = URL(
                        fileURLWithPath: document.source.location
                    )
                    guard FileManager.default.fileExists(atPath: sourceURL.path) else {
                        throw ProjectDocumentError.invalidSource
                    }
                    imported = try await importService.importLocalFile(sourceURL)
                case .remote:
                    guard let sourceURL = URL(string: document.source.location) else {
                        throw ProjectDocumentError.invalidSource
                    }
                    imported = try await importService.importRemoteURL(
                        sourceURL,
                        cacheRoot: preferences.cacheDirectoryURL
                    ) { [weak self] progress in
                        Task { @MainActor [weak self] in
                            guard let self, self.isImporting else { return }
                            self.importProgress = progress
                            self.statusMessage = progress < 0.10
                                ? self.t("status.searching_project_source")
                                : self.t("status.recovering_source", Int(progress * 100))
                        }
                    }
                }

                apply(imported)
                projectName = document.name
                regions = restoredRegions(
                    document.regions,
                    duration: imported.duration
                )
                selectedRegionID = regions.first?.id
                zoom = min(max(document.zoom, 1), 8)
                exportDirectoryURL = document.exportDirectoryPath.map {
                    URL(fileURLWithPath: $0, isDirectory: true)
                }
                currentProjectURL = projectURL
                sourceURL = document.source.kind == .remote
                    ? document.source.location
                    : ""
                seek(to: document.playhead)
                registerProject(document, at: projectURL)
                statusMessage = t("status.project_opened", document.name)
            } catch {
                isImporting = false
                importProgress = nil
                statusMessage = error.localizedDescription
                NSSound.beep()
            }
        }
    }

    private func writeProject(to url: URL) {
        do {
            let document = try projectDocument()
            try document.write(to: url)
            currentProjectURL = url
            registerProject(document, at: url)
            statusMessage = t("status.project_saved", url.lastPathComponent)
        } catch {
            statusMessage = error.localizedDescription
            NSSound.beep()
        }
    }

    private func projectDocument() throws -> NotchProjectDocument {
        let reference: ProjectSourceReference
        switch source.origin {
        case let .remote(url):
            reference = ProjectSourceReference(
                kind: .remote,
                location: url.absoluteString
            )
        case .local:
            guard let url = source.localURL else {
                throw ProjectDocumentError.noSource
            }
            reference = ProjectSourceReference(
                kind: .local,
                location: url.path(percentEncoded: false)
            )
        case .demo:
            throw ProjectDocumentError.noSource
        }

        return NotchProjectDocument(
            name: projectName,
            source: reference,
            regions: regions,
            exportDirectoryPath: exportDirectoryURL?.path(percentEncoded: false),
            playhead: playhead,
            zoom: zoom
        )
    }

    private func restoredRegions(
        _ savedRegions: [ClipRegion],
        duration: TimeInterval
    ) -> [ClipRegion] {
        savedRegions.compactMap { saved in
            var region = saved
            region.start = min(max(0, region.start), duration)
            region.end = min(max(region.start + 0.01, region.end), duration)
            return region.end - region.start >= 0.01 ? region : nil
        }
    }

    private func promptForExportDirectory() -> URL? {
        let panel = NSOpenPanel()
        panel.title = t("panel.export_folder")
        panel.prompt = t("panel.use_folder")
        panel.message = t("panel.remember_destination")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false
        panel.directoryURL = exportDirectoryURL
            ?? preferences.exportDirectoryURL
        guard panel.runModal() == .OK, let directory = panel.url else {
            return nil
        }
        exportDirectoryURL = directory
        return directory
    }

    private func availableExportDirectory() -> URL? {
        let preferred = exportDirectoryURL ?? preferences.exportDirectoryURL
        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: preferred.path,
            isDirectory: &isDirectory
        ), isDirectory.boolValue else {
            do {
                try FileManager.default.createDirectory(
                    at: preferred,
                    withIntermediateDirectories: true
                )
                exportDirectoryURL = preferred
                return preferred
            } catch {
                exportDirectoryURL = nil
                return nil
            }
        }
        exportDirectoryURL = preferred
        return preferred
    }

    private func safeProjectFilename() -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let cleaned = projectName
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? t("default.project_file") : cleaned
    }

    func openCatalogEntry(_ entry: ProjectCatalogEntry) {
        guard FileManager.default.fileExists(atPath: entry.projectPath) else {
            removeCatalogEntry(entry)
            statusMessage = t("status.project_missing")
            NSSound.beep()
            return
        }
        openProject(at: entry.projectURL)
    }

    func toggleConserved(_ entry: ProjectCatalogEntry) {
        guard let index = projectCatalog.firstIndex(where: {
            $0.projectPath == entry.projectPath
        }) else { return }
        projectCatalog[index].isConserved.toggle()
        persistProjectCatalog()
    }

    func removeCatalogEntry(_ entry: ProjectCatalogEntry) {
        projectCatalog.removeAll { $0.projectPath == entry.projectPath }
        persistProjectCatalog()
    }

    func revealCatalogEntry(_ entry: ProjectCatalogEntry) {
        guard FileManager.default.fileExists(atPath: entry.projectPath) else {
            removeCatalogEntry(entry)
            statusMessage = t("status.project_missing")
            return
        }
        NSWorkspace.shared.activateFileViewerSelecting([entry.projectURL])
    }

    private func registerProject(
        _ document: NotchProjectDocument,
        at url: URL
    ) {
        let path = url.standardizedFileURL.path(percentEncoded: false)
        let existing = projectCatalog.first {
            $0.projectPath == path
        }
        let entry = ProjectCatalogEntry(
            projectPath: path,
            name: document.name,
            sourceDescription: document.source.location,
            lastOpened: Date(),
            isConserved: existing?.isConserved ?? false
        )
        projectCatalog.removeAll { $0.projectPath == path }
        projectCatalog.append(entry)
        projectCatalog = Array(
            projectCatalog
                .sorted { $0.lastOpened > $1.lastOpened }
                .prefix(50)
        )
        persistProjectCatalog()
    }

    private func persistProjectCatalog() {
        if let data = try? JSONEncoder().encode(projectCatalog) {
            userDefaults.set(data, forKey: Self.projectCatalogKey)
        }
    }

    private static let projectCatalogKey = "NotchProjectCatalog.v1"

    private static func loadProjectCatalog(
        from userDefaults: UserDefaults
    ) -> [ProjectCatalogEntry] {
        guard let data = userDefaults.data(forKey: projectCatalogKey),
              let entries = try? JSONDecoder().decode(
                  [ProjectCatalogEntry].self,
                  from: data
              )
        else {
            return []
        }
        return entries.filter {
            FileManager.default.fileExists(atPath: $0.projectPath)
        }
    }

    func outputName(for region: ClipRegion, index: Int) -> String {
        "\(outputRelativePath(for: region, index: index)).\(preferences.outputFormat.fileExtension)"
    }

    private func outputRelativePath(
        for region: ClipRegion,
        index: Int
    ) -> String {
        let base = projectName.trimmingCharacters(in: .whitespacesAndNewlines)
        let clip = region.name.trimmingCharacters(in: .whitespacesAndNewlines)
        let safeBase = base.isEmpty ? "Notch" : base
        let safeClip = clip.isEmpty
            ? t("default.clip_file", index + 1)
            : clip
        switch preferences.namingConvention {
        case .baseDashClip:
            return "\(safeBase) - \(safeClip)"
        case .clipParenthesizedBase:
            return "\(safeClip) (\(safeBase))"
        case .baseFolderClip:
            return "\(safeBase)/\(safeClip)"
        }
    }

    func prepareForNewSource() {
        releasePlayer()
        regions.removeAll()
        selectedRegionID = nil
        playhead = 0
        isPlaying = false
        zoom = 1
        waveformSamples = []
        isAnalyzingWaveform = false
    }

    func apply(_ imported: ImportedMedia) {
        prepareForNewSource()
        source = AudioSource(
            id: UUID(),
            title: imported.title,
            subtitle: imported.subtitle,
            duration: imported.duration,
            origin: imported.origin,
            localURL: imported.localURL
        )
        projectName = imported.title
        hasLoadedSource = true
        isImporting = false
        importProgress = nil
        configurePlayer(url: imported.localURL)
        analyzeWaveform(url: imported.localURL)
    }

    private func configurePlayer(url: URL) {
        let newPlayer = AVPlayer(url: url)
        player = newPlayer

        timeObserver = newPlayer.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.05, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.handlePlaybackTime(time.seconds)
            }
        }

        playbackEndObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: newPlayer.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isPlaying = false
                self.previewEnd = nil
                self.playhead = self.source.duration
                self.statusMessage = self.t("status.playback_finished")
            }
        }
    }

    private func handlePlaybackTime(_ time: TimeInterval) {
        guard time.isFinite else { return }
        playhead = min(max(0, time), source.duration)

        if let previewEnd, time >= previewEnd {
            player?.pause()
            player?.seek(
                to: CMTime(seconds: previewEnd, preferredTimescale: 600),
                toleranceBefore: .zero,
                toleranceAfter: .zero
            )
            playhead = previewEnd
            self.previewEnd = nil
            isPlaying = false
            statusMessage = t("status.preview_finished")
        }
    }

    private func releasePlayer() {
        player?.pause()
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        if let playbackEndObserver {
            NotificationCenter.default.removeObserver(playbackEndObserver)
        }
        player = nil
        timeObserver = nil
        playbackEndObserver = nil
        previewEnd = nil
    }

    private func analyzeWaveform(url: URL) {
        isAnalyzingWaveform = true
        Task {
            do {
                let samples = try await waveformAnalyzer.analyze(url: url)
                guard source.localURL == url else { return }
                waveformSamples = samples
                isAnalyzingWaveform = false
                statusMessage = t("status.waveform_ready")
            } catch {
                guard source.localURL == url else { return }
                waveformSamples = []
                isAnalyzingWaveform = false
                statusMessage = t("status.waveform_failed")
            }
        }
    }
}
