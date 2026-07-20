@preconcurrency import AVFoundation
import AudioToolbox
import Foundation

private final class ExportSessionBox: @unchecked Sendable {
    let session: AVAssetExportSession

    init(_ session: AVAssetExportSession) {
        self.session = session
    }
}

struct AudioExportJob: Sendable {
    let region: ClipRegion
    let relativePath: String
}

enum AudioExportError: LocalizedError {
    case missingAudio
    case cannotCreateExporter
    case missingMP3Encoder
    case exportFailed(String)

    var errorDescription: String? {
        switch self {
        case .missingAudio:
            return L10n.string("error.missing_audio")
        case .cannotCreateExporter:
            return L10n.string("error.cannot_export")
        case .missingMP3Encoder:
            return L10n.string("error.missing_mp3_encoder")
        case let .exportFailed(message):
            return message.isEmpty ? L10n.string("error.export_failed") : message
        }
    }
}

actor AudioExportService {
    func export(
        sourceURL: URL,
        jobs: [AudioExportJob],
        destinationDirectory: URL,
        format: AudioOutputFormat = .m4a,
        progress: @escaping @Sendable (Double) -> Void = { _ in }
    ) async throws -> [URL] {
        guard !jobs.isEmpty else { return [] }

        var exportedURLs: [URL] = []
        for (index, job) in jobs.enumerated() {
            let destination = try availableURL(
                relativePath: job.relativePath,
                format: format,
                in: destinationDirectory
            )
            try await exportRegion(
                sourceURL: sourceURL,
                region: job.region,
                destinationURL: destination,
                format: format
            ) { regionProgress in
                progress(
                    (Double(index) + regionProgress)
                        / Double(jobs.count)
                )
            }
            exportedURLs.append(destination)
            progress(Double(index + 1) / Double(jobs.count))
        }
        return exportedURLs
    }

    private func exportRegion(
        sourceURL: URL,
        region: ClipRegion,
        destinationURL: URL,
        format: AudioOutputFormat,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        switch format {
        case .m4a:
            try await exportM4A(
                sourceURL: sourceURL,
                region: region,
                destinationURL: destinationURL,
                progress: progress
            )
        case .wav:
            try exportWAV(
                sourceURL: sourceURL,
                region: region,
                destinationURL: destinationURL,
                progress: progress
            )
        case .mp3:
            try exportMP3(
                sourceURL: sourceURL,
                region: region,
                destinationURL: destinationURL,
                progress: progress
            )
        }
    }

    private func exportM4A(
        sourceURL: URL,
        region: ClipRegion,
        destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws {
        let asset = AVURLAsset(url: sourceURL)
        guard let exporter = AVAssetExportSession(
            asset: asset,
            presetName: AVAssetExportPresetAppleM4A
        ) else {
            throw AudioExportError.cannotCreateExporter
        }

        exporter.outputURL = destinationURL
        exporter.outputFileType = .m4a
        exporter.shouldOptimizeForNetworkUse = false
        exporter.timeRange = CMTimeRange(
            start: CMTime(seconds: region.start, preferredTimescale: 600),
            duration: CMTime(seconds: region.duration, preferredTimescale: 600)
        )

        let box = ExportSessionBox(exporter)
        let progressMonitor = Task.detached {
            while !Task.isCancelled {
                progress(Double(box.session.progress))
                try? await Task.sleep(for: .milliseconds(100))
            }
        }
        defer { progressMonitor.cancel() }

        try await withCheckedThrowingContinuation { continuation in
            exporter.exportAsynchronously {
                switch box.session.status {
                case .completed:
                    continuation.resume()
                case .failed, .cancelled:
                    continuation.resume(
                        throwing: AudioExportError.exportFailed(
                            box.session.error?.localizedDescription ?? ""
                        )
                    )
                default:
                    continuation.resume(
                        throwing: AudioExportError.exportFailed(
                            L10n.string("error.unexpected_export_state")
                        )
                    )
                }
            }
        }
    }

    private func exportWAV(
        sourceURL: URL,
        region: ClipRegion,
        destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) throws {
        let input = try AVAudioFile(forReading: sourceURL)
        let processingFormat = input.processingFormat
        let sampleRate = processingFormat.sampleRate
        let startFrame = AVAudioFramePosition(region.start * sampleRate)
        let requestedFrames = AVAudioFramePosition(region.duration * sampleRate)
        input.framePosition = min(max(0, startFrame), input.length)

        let settings: [String: Any] = [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: processingFormat.channelCount,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false
        ]
        let output = try AVAudioFile(
            forWriting: destinationURL,
            settings: settings
        )

        var remaining = min(requestedFrames, input.length - input.framePosition)
        let total = max(remaining, 1)
        let chunkSize: AVAudioFrameCount = 32_768

        while remaining > 0 {
            let frameCount = AVAudioFrameCount(
                min(AVAudioFramePosition(chunkSize), remaining)
            )
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: processingFormat,
                frameCapacity: frameCount
            ) else {
                throw AudioExportError.cannotCreateExporter
            }
            try input.read(into: buffer, frameCount: frameCount)
            guard buffer.frameLength > 0 else { break }
            try output.write(from: buffer)
            remaining -= AVAudioFramePosition(buffer.frameLength)
            progress(1 - Double(remaining) / Double(total))
        }
        progress(1)
    }

    private func exportMP3(
        sourceURL: URL,
        region: ClipRegion,
        destinationURL: URL,
        progress: @escaping @Sendable (Double) -> Void
    ) throws {
        guard let encoder = Bundle.module.url(
            forResource: "lame",
            withExtension: nil
        ) else {
            throw AudioExportError.missingMP3Encoder
        }

        let temporaryWAV = FileManager.default.temporaryDirectory
            .appendingPathComponent("notch-\(UUID().uuidString).wav")
        defer { try? FileManager.default.removeItem(at: temporaryWAV) }

        try exportWAV(
            sourceURL: sourceURL,
            region: region,
            destinationURL: temporaryWAV
        ) { wavProgress in
            progress(wavProgress * 0.75)
        }

        let process = Process()
        let errorPipe = Pipe()
        process.executableURL = encoder
        process.arguments = [
            "--silent",
            "-V", "2",
            temporaryWAV.path(percentEncoded: false),
            destinationURL.path(percentEncoded: false)
        ]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = errorPipe
        progress(0.82)
        try process.run()
        let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let message = String(data: errorData, encoding: .utf8) ?? ""
            throw AudioExportError.exportFailed(
                message.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        progress(1)
    }

    private func availableURL(
        relativePath: String,
        format: AudioOutputFormat,
        in directory: URL
    ) throws -> URL {
        let components = relativePath
            .split(separator: "/", omittingEmptySubsequences: true)
            .map { sanitizedComponent(String($0)) }
        let safeComponents = components.isEmpty ? ["Recorte"] : components
        let folderComponents = safeComponents.dropLast()
        var destinationDirectory = directory
        for component in folderComponents {
            destinationDirectory.appendPathComponent(
                component,
                isDirectory: true
            )
        }
        try FileManager.default.createDirectory(
            at: destinationDirectory,
            withIntermediateDirectories: true
        )

        let filename = safeComponents.last ?? "Recorte"
        let base = (filename as NSString).deletingPathExtension
        let requested = destinationDirectory.appendingPathComponent(
            "\(base).\(format.fileExtension)"
        )
        guard FileManager.default.fileExists(atPath: requested.path) else {
            return requested
        }

        let requestedBase = requested.deletingPathExtension().lastPathComponent
        var suffix = 2
        while true {
            let candidate = destinationDirectory.appendingPathComponent(
                "\(requestedBase) \(suffix).\(format.fileExtension)"
            )
            if !FileManager.default.fileExists(atPath: candidate.path) {
                return candidate
            }
            suffix += 1
        }
    }

    private func sanitizedComponent(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: ":\\?%*|\"<>")
        let cleaned = value
            .components(separatedBy: invalid)
            .joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? "Recorte" : cleaned
    }
}
