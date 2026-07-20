import SwiftUI

struct TimelineView: View {
    @Bindable var store: EditorStore
    @State private var interaction: Interaction?
    @State private var draftSelection: ClosedRange<TimeInterval>?

    private enum Interaction {
        case empty(anchor: TimeInterval)
        case moving(
            id: ClipRegion.ID,
            originalStart: TimeInterval,
            originalEnd: TimeInterval
        )
        case resizingStart(id: ClipRegion.ID, originalStart: TimeInterval)
        case resizingEnd(id: ClipRegion.ID, originalEnd: TimeInterval)
    }

    var body: some View {
        GeometryReader { viewport in
            ScrollView(.horizontal) {
                VStack(spacing: 8) {
                    timelineCanvas(width: canvasWidth(for: viewport.size.width))
                        .frame(height: 185)

                    TimelineRuler(duration: store.source.duration)
                        .frame(
                            width: canvasWidth(for: viewport.size.width),
                            height: 22
                        )
                }
            }
            .scrollIndicators(.visible)
            .contentMargins(.horizontal, 0, for: .scrollContent)
        }
        .frame(height: 225)
    }

    private func timelineCanvas(width: CGFloat) -> some View {
        GeometryReader { geometry in
            let size = geometry.size

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.22))

                WaveformShape(samples: displayedSamples)
                    .fill(Color.secondary.opacity(0.25))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 25)
                    .allowsHitTesting(false)

                if let draftSelection {
                    draftOverlay(draftSelection, in: size)
                }

                ForEach(store.regions) { region in
                    regionOverlay(region, in: size)
                        .zIndex(store.selectedRegionID == region.id ? 20 : 10)
                }

                playhead(in: size)
                    .zIndex(30)
            }
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .contentShape(Rectangle())
            .gesture(timelineGesture(width: size.width))
        }
        .frame(width: width)
    }

    @ViewBuilder
    private func regionOverlay(_ region: ClipRegion, in size: CGSize) -> some View {
        let x = xPosition(for: region.start, width: size.width)
        let endX = xPosition(for: region.end, width: size.width)
        let width = max(8, endX - x)
        let color = NotchPalette.regionColors[region.colorIndex % NotchPalette.regionColors.count]
        let selected = store.selectedRegionID == region.id
        let handleWidth: CGFloat = 9

        ZStack(alignment: .topLeading) {
            Rectangle()
                .fill(color.opacity(region.isEnabled ? 0.17 : 0.06))
                .frame(width: width, height: size.height)
                .offset(x: x)

            WaveformShape(samples: displayedSamples)
                .fill(color.opacity(region.isEnabled ? 0.92 : 0.32))
                .padding(.horizontal, 10)
                .padding(.vertical, 25)
                .frame(width: size.width, height: size.height)
                .mask(alignment: .topLeading) {
                    Rectangle()
                        .frame(width: width, height: size.height)
                        .offset(x: x)
                }

            VStack {
                HStack(spacing: 5) {
                    Text(region.name)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(Timecode.string(from: region.duration, includeMilliseconds: false))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 9)
                Spacer()
            }
            .frame(width: width, height: size.height)
            .offset(x: x)

            HStack(spacing: 0) {
                resizeHandle(color: color)
                    .frame(width: handleWidth, height: size.height)

                Spacer(minLength: 0)

                resizeHandle(color: color)
                    .frame(width: handleWidth, height: size.height)
            }
            .frame(width: width, height: size.height, alignment: .leading)
            .offset(x: x)

            RoundedRectangle(cornerRadius: 5)
                .stroke(color.opacity(selected ? 1 : 0.55), lineWidth: selected ? 2 : 1)
                .frame(width: width, height: size.height)
                .offset(x: x)
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(region.name), desde \(Timecode.string(from: region.start)) hasta \(Timecode.string(from: region.end))")
    }

    private func resizeHandle(color: Color) -> some View {
        RoundedRectangle(cornerRadius: 3)
            .fill(color)
            .frame(width: 9)
            .overlay {
                Capsule()
                    .fill(.white.opacity(0.72))
                    .frame(width: 2, height: 28)
            }
            .contentShape(Rectangle().inset(by: -6))
    }

    @ViewBuilder
    private func draftOverlay(_ range: ClosedRange<TimeInterval>, in size: CGSize) -> some View {
        let x = xPosition(for: range.lowerBound, width: size.width)
        let endX = xPosition(for: range.upperBound, width: size.width)

        RoundedRectangle(cornerRadius: 5)
            .fill(NotchPalette.accent.opacity(0.16))
            .overlay {
                RoundedRectangle(cornerRadius: 5)
                    .stroke(
                        NotchPalette.accent,
                        style: StrokeStyle(lineWidth: 2, dash: [6, 4])
                    )
            }
            .frame(width: max(2, endX - x), height: size.height)
            .position(x: x + max(2, endX - x) / 2, y: size.height / 2)
            .allowsHitTesting(false)
    }

    @ViewBuilder
    private func playhead(in size: CGSize) -> some View {
        let x = xPosition(for: store.playhead, width: size.width)

        VStack(spacing: 0) {
            Image(systemName: "triangle.fill")
                .font(.system(size: 9))
                .rotationEffect(.degrees(180))
                .foregroundStyle(.white)
            Rectangle()
                .fill(.white)
                .frame(width: 1, height: max(0, size.height - 8))
        }
        .shadow(color: .black.opacity(0.45), radius: 2)
        .position(x: x, y: size.height / 2)
        .allowsHitTesting(false)
    }

    private func timelineGesture(width: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { value in
                if interaction == nil {
                    interaction = interaction(
                        at: value.startLocation.x,
                        width: width
                    )
                    selectInteractionRegion()
                }

                let delta = timeDelta(for: value.translation.width, width: width)

                if case let .empty(anchor) = interaction {
                    let current = time(for: value.location.x, width: width)
                    if abs(value.translation.width) < 4 {
                        store.seek(to: current)
                        draftSelection = nil
                    } else {
                        draftSelection = min(anchor, current)...max(anchor, current)
                    }
                } else if case let .moving(id, originalStart, originalEnd) = interaction {
                    guard abs(value.translation.width) >= 2 else { return }
                    let duration = originalEnd - originalStart
                    let newStart = min(
                        max(0, originalStart + delta),
                        max(0, store.source.duration - duration)
                    )
                    store.setRegionBounds(
                        id: id,
                        start: newStart,
                        end: newStart + duration
                    )
                } else if case let .resizingStart(id, originalStart) = interaction,
                          let region = store.regions.first(where: { $0.id == id }) {
                    store.setRegionBounds(
                        id: id,
                        start: min(max(0, originalStart + delta), region.end - 0.01)
                    )
                } else if case let .resizingEnd(id, originalEnd) = interaction,
                          let region = store.regions.first(where: { $0.id == id }) {
                    store.setRegionBounds(
                        id: id,
                        end: max(
                            region.start + 0.01,
                            min(store.source.duration, originalEnd + delta)
                        )
                    )
                }
            }
            .onEnded { value in
                if case let .empty(anchor) = interaction,
                   abs(value.translation.width) >= 4 {
                    let end = time(for: value.location.x, width: width)
                    store.addRegion(from: anchor, to: end)
                }

                draftSelection = nil
                interaction = nil
            }
    }

    private func interaction(at horizontalPosition: CGFloat, width: CGFloat) -> Interaction {
        let touchedTime = time(for: horizontalPosition, width: width)
        let edgeTolerance = store.source.duration * TimeInterval(11 / max(width, 1))
        let target = TimelineHitTesting.resolve(
            time: touchedTime,
            edgeTolerance: edgeTolerance,
            regions: store.regions,
            selectedRegionID: store.selectedRegionID
        )

        switch target {
        case let .start(id):
            guard let region = store.regions.first(where: { $0.id == id }) else {
                return .empty(anchor: touchedTime)
            }
            return .resizingStart(id: id, originalStart: region.start)
        case let .body(id):
            guard let region = store.regions.first(where: { $0.id == id }) else {
                return .empty(anchor: touchedTime)
            }
            return .moving(
                id: id,
                originalStart: region.start,
                originalEnd: region.end
            )
        case let .end(id):
            guard let region = store.regions.first(where: { $0.id == id }) else {
                return .empty(anchor: touchedTime)
            }
            return .resizingEnd(id: id, originalEnd: region.end)
        case .empty:
            return .empty(anchor: touchedTime)
        }
    }

    private func selectInteractionRegion() {
        let id: ClipRegion.ID?
        switch interaction {
        case let .moving(regionID, _, _),
             let .resizingStart(regionID, _),
             let .resizingEnd(regionID, _):
            id = regionID
        case .empty, .none:
            id = nil
        }

        guard let id,
              let region = store.regions.first(where: { $0.id == id }) else { return }
        store.selectedRegionID = id
        store.statusMessage = "“\(region.name)” seleccionado desde la línea de tiempo"
    }

    private func canvasWidth(for viewportWidth: CGFloat) -> CGFloat {
        max(1, viewportWidth) * CGFloat(store.zoom)
    }

    private func xPosition(for time: TimeInterval, width: CGFloat) -> CGFloat {
        guard store.source.duration > 0 else { return 0 }
        return CGFloat(time / store.source.duration) * width
    }

    private func time(for x: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return min(
            max(0, TimeInterval(x / width) * store.source.duration),
            store.source.duration
        )
    }

    private func timeDelta(for horizontalPoints: CGFloat, width: CGFloat) -> TimeInterval {
        guard width > 0 else { return 0 }
        return TimeInterval(horizontalPoints / width) * store.source.duration
    }

    private var displayedSamples: [CGFloat] {
        if store.waveformSamples.count > 1 {
            return store.waveformSamples
        }
        return Array(repeating: 0.06, count: 360)
    }
}

private struct WaveformShape: Shape {
    let samples: [CGFloat]

    func path(in rect: CGRect) -> Path {
        var path = Path()
        guard samples.count > 1 else { return path }

        let middle = rect.midY
        let step = rect.width / CGFloat(samples.count - 1)
        let maxAmplitude = rect.height / 2

        path.move(to: CGPoint(x: rect.minX, y: middle))

        for (index, sample) in samples.enumerated() {
            let x = rect.minX + CGFloat(index) * step
            path.addLine(to: CGPoint(x: x, y: middle - sample * maxAmplitude))
        }

        for (index, sample) in samples.enumerated().reversed() {
            let x = rect.minX + CGFloat(index) * step
            path.addLine(to: CGPoint(x: x, y: middle + sample * maxAmplitude))
        }

        path.closeSubpath()
        return path
    }
}

private struct TimelineRuler: View {
    let duration: TimeInterval

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .topLeading) {
                ForEach(0...16, id: \.self) { index in
                    let fraction = CGFloat(index) / 16
                    let x = fraction * geometry.size.width
                    let labelX = min(max(x, 26), max(26, geometry.size.width - 26))

                    Rectangle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 1, height: index.isMultiple(of: 2) ? 7 : 4)
                        .position(x: x, y: 3.5)

                    if index.isMultiple(of: 2) {
                        Text(
                            Timecode.string(
                                from: duration * Double(fraction),
                                includeMilliseconds: false
                            )
                        )
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .fixedSize()
                        .position(x: labelX, y: 15)
                    }
                }
            }
        }
    }
}
