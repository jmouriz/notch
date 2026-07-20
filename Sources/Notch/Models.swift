import Foundation
import SwiftUI

struct AudioSource: Identifiable, Hashable, Sendable {
    let id: UUID
    var title: String
    var subtitle: String
    var duration: TimeInterval
    var origin: Origin
    var localURL: URL?

    enum Origin: Hashable, Sendable {
        case local
        case remote(URL)
        case demo
    }

    static let empty = AudioSource(
        id: UUID(),
        title: "Sin fuente",
        subtitle: "Pegá una dirección o abrí un archivo",
        duration: 0,
        origin: .demo,
        localURL: nil
    )
}

struct ClipRegion: Identifiable, Hashable, Codable, Sendable {
    let id: UUID
    var start: TimeInterval
    var end: TimeInterval
    var name: String
    var isEnabled: Bool
    var colorIndex: Int

    var duration: TimeInterval {
        max(0, end - start)
    }

    init(
        id: UUID = UUID(),
        start: TimeInterval,
        end: TimeInterval,
        name: String,
        isEnabled: Bool = true,
        colorIndex: Int = 0
    ) {
        self.id = id
        self.start = start
        self.end = end
        self.name = name
        self.isEnabled = isEnabled
        self.colorIndex = colorIndex
    }
}

enum TimelineHitTarget: Equatable, Sendable {
    case start(ClipRegion.ID)
    case body(ClipRegion.ID)
    case end(ClipRegion.ID)
    case empty
}

enum TimelineHitTesting {
    static func resolve(
        time: TimeInterval,
        edgeTolerance: TimeInterval,
        regions: [ClipRegion],
        selectedRegionID: ClipRegion.ID?
    ) -> TimelineHitTarget {
        let orderedRegions = ordered(
            regions,
            selectedRegionID: selectedRegionID
        )

        for region in orderedRegions {
            if abs(time - region.start) <= edgeTolerance {
                return .start(region.id)
            }
            if abs(time - region.end) <= edgeTolerance {
                return .end(region.id)
            }
        }

        if let region = orderedRegions.first(where: {
            time >= $0.start && time <= $0.end
        }) {
            return .body(region.id)
        }

        return .empty
    }

    private static func ordered(
        _ regions: [ClipRegion],
        selectedRegionID: ClipRegion.ID?
    ) -> [ClipRegion] {
        var result: [ClipRegion] = []
        if let selected = regions.first(where: { $0.id == selectedRegionID }) {
            result.append(selected)
        }
        result.append(
            contentsOf: regions.reversed().filter {
                $0.id != selectedRegionID
            }
        )
        return result
    }
}

enum NotchPalette {
    static let accent = Color(red: 0.12, green: 0.87, blue: 0.85)
    static let secondaryAccent = Color(red: 0.36, green: 0.62, blue: 1)
    static let panel = Color(nsColor: .controlBackgroundColor)

    static let regionColors: [Color] = [
        accent,
        secondaryAccent,
        Color(red: 0.72, green: 0.45, blue: 1),
        Color(red: 1, green: 0.55, blue: 0.34)
    ]
}

enum Timecode {
    static func string(from seconds: TimeInterval, includeMilliseconds: Bool = true) -> String {
        guard seconds.isFinite else { return "00:00.000" }
        let clamped = max(0, seconds)
        let minutes = Int(clamped) / 60
        let wholeSeconds = Int(clamped) % 60
        let milliseconds = Int((clamped - floor(clamped)) * 1_000)

        if includeMilliseconds {
            return String(format: "%02d:%02d.%03d", minutes, wholeSeconds, milliseconds)
        }
        return String(format: "%02d:%02d", minutes, wholeSeconds)
    }

    static func seconds(from value: String) -> TimeInterval? {
        let normalized = value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")

        if let direct = TimeInterval(normalized), direct >= 0 {
            return direct
        }

        let parts = normalized.split(separator: ":").map(String.init)
        guard parts.count == 2 || parts.count == 3 else { return nil }
        guard let last = TimeInterval(parts.last ?? "") else { return nil }

        if parts.count == 2, let minutes = TimeInterval(parts[0]) {
            return minutes * 60 + last
        }

        if parts.count == 3,
           let hours = TimeInterval(parts[0]),
           let minutes = TimeInterval(parts[1]) {
            return hours * 3_600 + minutes * 60 + last
        }
        return nil
    }
}
