import AVFoundation
import Foundation

private final class ProcessOutputCollector: @unchecked Sendable {
    private let lock = NSLock()
    private let finished = DispatchSemaphore(value: 0)
    private var output = Data()
    private var pending = Data()
    private let progress: @Sendable (Double) -> Void

    init(progress: @escaping @Sendable (Double) -> Void) {
        self.progress = progress
    }

    func consume(_ data: Data) {
        guard !data.isEmpty else {
            flushPending()
            finished.signal()
            return
        }

        lock.lock()
        output.append(data)
        pending.append(data)
        let lines = completeLines()
        lock.unlock()

        lines.forEach(reportProgress)
    }

    func waitForCompletion() -> Data {
        _ = finished.wait(timeout: .now() + 2)
        lock.lock()
        defer { lock.unlock() }
        return output
    }

    private func completeLines() -> [String] {
        var lines: [String] = []
        while let newline = pending.firstIndex(of: 0x0A) {
            let lineData = pending[..<newline]
            pending.removeSubrange(...newline)
            if let line = String(data: lineData, encoding: .utf8) {
                lines.append(line)
            }
        }
        return lines
    }

    private func flushPending() {
        lock.lock()
        let remaining = String(data: pending, encoding: .utf8)
        pending.removeAll()
        lock.unlock()
        if let remaining {
            reportProgress(remaining)
        }
    }

    private func reportProgress(_ line: String) {
        guard let marker = line.range(of: "NOTCH_PROGRESS:") else { return }
        let rawValue = line[marker.upperBound...]
            .replacingOccurrences(of: "%", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let percentage = Double(rawValue) else { return }
        progress(min(max(percentage / 100, 0), 1))
    }
}

struct ImportedMedia: Sendable {
    let title: String
    let subtitle: String
    let duration: TimeInterval
    let localURL: URL
    let origin: AudioSource.Origin
    let wasCached: Bool
}

enum MediaImportError: LocalizedError {
    case missingDownloader
    case invalidMetadata
    case unsupportedAudio
    case commandFailed(String)
    case downloadedFileMissing

    var errorDescription: String? {
        switch self {
        case .missingDownloader:
            return L10n.string("error.missing_downloader")
        case .invalidMetadata:
            return L10n.string("error.invalid_metadata")
        case .unsupportedAudio:
            return L10n.string("error.unsupported_audio")
        case let .commandFailed(message):
            return message.isEmpty ? L10n.string("error.import_failed") : message
        case .downloadedFileMissing:
            return L10n.string("error.download_missing")
        }
    }
}

actor MediaImportService {
    private struct RemoteMetadata: Codable {
        let id: String
        let title: String
        let duration: TimeInterval?
        let channel: String?

        enum CodingKeys: String, CodingKey {
            case id
            case title
            case duration
            case channel
            case uploader
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(String.self, forKey: .id)
            title = try container.decode(String.self, forKey: .title)
            duration = try container.decodeIfPresent(TimeInterval.self, forKey: .duration)
            channel =
                try container.decodeIfPresent(String.self, forKey: .channel)
                ?? container.decodeIfPresent(String.self, forKey: .uploader)
        }

        init(id: String, title: String, duration: TimeInterval?, channel: String?) {
            self.id = id
            self.title = title
            self.duration = duration
            self.channel = channel
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(title, forKey: .title)
            try container.encodeIfPresent(duration, forKey: .duration)
            try container.encodeIfPresent(channel, forKey: .channel)
        }
    }

    private struct ProcessResult {
        let stdout: Data
        let stderr: Data
        let status: Int32
    }

    func importLocalFile(_ url: URL) async throws -> ImportedMedia {
        let asset = AVURLAsset(url: url)
        let durationValue = try await asset.load(.duration)
        let audioTracks = try await asset.loadTracks(withMediaType: .audio)
        guard !audioTracks.isEmpty else {
            throw MediaImportError.unsupportedAudio
        }

        let duration = durationValue.seconds
        guard duration.isFinite, duration > 0 else {
            throw MediaImportError.unsupportedAudio
        }

        return ImportedMedia(
            title: url.deletingPathExtension().lastPathComponent,
            subtitle: url.path(percentEncoded: false),
            duration: duration,
            localURL: url,
            origin: .local,
            wasCached: false
        )
    }

    func importRemoteURL(
        _ url: URL,
        cacheRoot: URL? = nil,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> ImportedMedia {
        progress(0.02)

        if let identifier = Self.youtubeIdentifier(from: url),
           let cached = cachedImportedMedia(
               identifier: identifier,
               originURL: url,
               cacheRoot: cacheRoot
           ) {
            progress(1)
            return cached
        }

        let downloader = try downloaderURL()
        let metadataResult = try run(
            executable: downloader,
            arguments: [
                "--no-playlist",
                "--no-warnings",
                "--dump-single-json",
                "--skip-download",
                url.absoluteString
            ]
        )
        guard metadataResult.status == 0 else {
            throw commandError(from: metadataResult)
        }

        let metadata: RemoteMetadata
        do {
            metadata = try JSONDecoder().decode(RemoteMetadata.self, from: metadataResult.stdout)
        } catch {
            throw MediaImportError.invalidMetadata
        }
        progress(0.10)

        let directory = try cacheDirectory(
            for: metadata.id,
            root: cacheRoot
        )
        let manifestURL = directory.appendingPathComponent("metadata.json")

        if let cachedAudio = cachedAudioURL(in: directory) {
            try? JSONEncoder().encode(metadata).write(to: manifestURL, options: .atomic)
            progress(1)
            return importedMedia(
                metadata: metadata,
                localURL: cachedAudio,
                originURL: url,
                wasCached: true
            )
        }

        let outputTemplate = directory
            .appendingPathComponent("source.%(ext)s")
            .path(percentEncoded: false)
        let downloadResult = try runWithProgress(
            executable: downloader,
            arguments: [
                "--no-playlist",
                "--no-warnings",
                "--newline",
                "--progress",
                "--progress-template", "download:NOTCH_PROGRESS:%(progress._percent_str)s",
                "--no-part",
                "-f", "bestaudio[ext=m4a]/bestaudio[acodec^=mp4a]",
                "-o", outputTemplate,
                url.absoluteString
            ],
            progress: { downloadProgress in
                progress(0.10 + downloadProgress * 0.88)
            }
        )
        guard downloadResult.status == 0 else {
            throw commandError(from: downloadResult)
        }

        guard let audioURL = cachedAudioURL(in: directory) else {
            throw MediaImportError.downloadedFileMissing
        }

        try JSONEncoder().encode(metadata).write(to: manifestURL, options: .atomic)
        progress(1)
        return importedMedia(
            metadata: metadata,
            localURL: audioURL,
            originURL: url,
            wasCached: false
        )
    }

    private func importedMedia(
        metadata: RemoteMetadata,
        localURL: URL,
        originURL: URL,
        wasCached: Bool
    ) -> ImportedMedia {
        ImportedMedia(
            title: metadata.title,
            subtitle: metadata.channel ?? originURL.host() ?? originURL.absoluteString,
            duration: metadata.duration ?? 0,
            localURL: localURL,
            origin: .remote(originURL),
            wasCached: wasCached
        )
    }

    private func cachedImportedMedia(
        identifier: String,
        originURL: URL,
        cacheRoot: URL?
    ) -> ImportedMedia? {
        guard let directory = try? cacheDirectory(
            for: identifier,
            root: cacheRoot
        ),
              let audioURL = cachedAudioURL(in: directory),
              let data = try? Data(
                  contentsOf: directory.appendingPathComponent("metadata.json")
              ),
              let metadata = try? JSONDecoder().decode(RemoteMetadata.self, from: data)
        else {
            return nil
        }

        return importedMedia(
            metadata: metadata,
            localURL: audioURL,
            originURL: originURL,
            wasCached: true
        )
    }

    static func youtubeIdentifier(from url: URL) -> String? {
        guard let components = URLComponents(
            url: url,
            resolvingAgainstBaseURL: false
        ) else {
            return nil
        }

        let host = (components.host ?? "").lowercased()
        if host == "youtu.be" || host.hasSuffix(".youtu.be") {
            return url.pathComponents
                .dropFirst()
                .first
                .flatMap(validYouTubeIdentifier)
        }

        guard host == "youtube.com" || host.hasSuffix(".youtube.com") else {
            return nil
        }

        if let identifier = components.queryItems?
            .first(where: { $0.name == "v" })?
            .value
            .flatMap(validYouTubeIdentifier) {
            return identifier
        }

        let path = url.pathComponents.filter { $0 != "/" }
        guard path.count >= 2,
              ["embed", "shorts", "live"].contains(path[0].lowercased())
        else {
            return nil
        }
        return validYouTubeIdentifier(path[1])
    }

    private static func validYouTubeIdentifier(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.range(
            of: #"^[A-Za-z0-9_-]{6,32}$"#,
            options: .regularExpression
        ) != nil else {
            return nil
        }
        return trimmed
    }

    private func downloaderURL() throws -> URL {
        if let bundledInTools = Bundle.module.url(
            forResource: "yt-dlp",
            withExtension: nil,
            subdirectory: "Tools"
        ) {
            return bundledInTools
        }
        if let bundled = Bundle.module.url(
            forResource: "yt-dlp",
            withExtension: nil
        ) {
            return bundled
        }
        throw MediaImportError.missingDownloader
    }

    private func cacheDirectory(
        for identifier: String,
        root customRoot: URL?
    ) throws -> URL {
        let root: URL
        if let customRoot {
            root = customRoot
        } else {
            let base = try FileManager.default.url(
                for: .cachesDirectory,
                in: .userDomainMask,
                appropriateFor: nil,
                create: true
            )
            root = base
                .appendingPathComponent("ar.tecnologica.notch", isDirectory: true)
                .appendingPathComponent("Media", isDirectory: true)
        }
        let safeIdentifier = identifier.replacingOccurrences(
            of: #"[^A-Za-z0-9_-]"#,
            with: "_",
            options: .regularExpression
        )
        let directory = root
            .appendingPathComponent(safeIdentifier, isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        return directory
    }

    private func cachedAudioURL(in directory: URL) -> URL? {
        let supportedExtensions = Set(["m4a", "mp4", "aac"])
        return try? FileManager.default
            .contentsOfDirectory(
                at: directory,
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles]
            )
            .first {
                $0.lastPathComponent.hasPrefix("source.")
                    && supportedExtensions.contains($0.pathExtension.lowercased())
            }
    }

    private func run(executable: URL, arguments: [String]) throws -> ProcessResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError

        try process.run()
        let outputData = standardOutput.fileHandleForReading.readDataToEndOfFile()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()

        return ProcessResult(
            stdout: outputData,
            stderr: errorData,
            status: process.terminationStatus
        )
    }

    private func runWithProgress(
        executable: URL,
        arguments: [String],
        progress: @escaping @Sendable (Double) -> Void
    ) throws -> ProcessResult {
        let process = Process()
        let standardOutput = Pipe()
        let standardError = Pipe()
        let collector = ProcessOutputCollector(progress: progress)
        process.executableURL = executable
        process.arguments = arguments
        process.standardOutput = standardOutput
        process.standardError = standardError
        standardOutput.fileHandleForReading.readabilityHandler = { handle in
            collector.consume(handle.availableData)
        }

        try process.run()
        let errorData = standardError.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        let outputData = collector.waitForCompletion()
        standardOutput.fileHandleForReading.readabilityHandler = nil

        return ProcessResult(
            stdout: outputData,
            stderr: errorData,
            status: process.terminationStatus
        )
    }

    private func commandError(from result: ProcessResult) -> MediaImportError {
        let errorText = String(data: result.stderr, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let outputText = String(data: result.stdout, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return .commandFailed(errorText ?? outputText ?? "")
    }
}
