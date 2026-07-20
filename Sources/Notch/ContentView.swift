import SwiftUI

struct ContentView: View {
    @Bindable var store: EditorStore

    var body: some View {
        NavigationSplitView {
            LibrarySidebar(store: store)
                .navigationSplitViewColumnWidth(min: 220, ideal: 250, max: 310)
        } detail: {
            switch store.librarySelection {
            case .current:
                EditorWorkspace(store: store)
            case .recent:
                ProjectLibraryView(
                    store: store,
                    title: "Recientes",
                    description: "Proyectos de Notch abiertos o guardados recientemente.",
                    entries: store.recentProjects
                )
            case .conserved:
                ProjectLibraryView(
                    store: store,
                    title: "Conservados",
                    description: "Proyectos fijados para mantenerlos siempre a mano.",
                    entries: store.conservedProjects
                )
            }
        }
        .tint(NotchPalette.accent)
    }
}

private struct EditorWorkspace: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            SourceBar(store: store)
            Divider()
            if store.hasLoadedSource {
                EditorHeader(store: store)
                TimelineView(store: store)
                    .padding(.horizontal, 22)
                    .padding(.bottom, 18)
            } else {
                EmptyEditorView(store: store)
            }
            Divider()
            ClipList(store: store)
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            StatusBar(store: store)
        }
    }
}

private struct LibrarySidebar: View {
    @Bindable var store: EditorStore

    var body: some View {
        List(selection: $store.librarySelection) {
            Section("Biblioteca") {
                Label("Proyecto actual", systemImage: "waveform.path")
                    .tag(LibraryDestination.current)
                Label("Recientes", systemImage: "clock")
                    .badge(store.recentProjects.count)
                    .tag(LibraryDestination.recent)
                Label("Conservados", systemImage: "pin")
                    .badge(store.conservedProjects.count)
                    .tag(LibraryDestination.conserved)
            }

            Section("Fuente actual") {
                if store.hasLoadedSource {
                    VStack(alignment: .leading, spacing: 5) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(
                                LinearGradient(
                                    colors: [.black.opacity(0.9), NotchPalette.accent.opacity(0.35)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(height: 94)
                            .overlay {
                                Image(systemName: "waveform")
                                    .font(.system(size: 31, weight: .medium))
                                    .foregroundStyle(NotchPalette.accent)
                            }

                        Text(store.source.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(store.source.subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                    .padding(.vertical, 5)
                } else {
                    Label("Ninguna fuente cargada", systemImage: "waveform.slash")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 5)
                }
            }
        }
        .listStyle(.sidebar)
        .navigationTitle("Notch")
    }
}

private struct ProjectLibraryView: View {
    @Bindable var store: EditorStore
    let title: String
    let description: String
    let entries: [ProjectCatalogEntry]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.largeTitle.bold())
                    Text(description)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: store.openProject) {
                    Label("Abrir proyecto…", systemImage: "folder")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)

            Divider()

            if entries.isEmpty {
                ContentUnavailableView(
                    title,
                    systemImage: title == "Conservados" ? "pin.slash" : "clock",
                    description: Text(
                        title == "Conservados"
                            ? "Fijá un proyecto desde Recientes para conservarlo."
                            : "Los proyectos que guardes o abras aparecerán acá."
                    )
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(entries) { entry in
                    ProjectCatalogRow(store: store, entry: entry)
                }
                .listStyle(.inset)
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .safeAreaInset(edge: .bottom) {
            StatusBar(store: store)
        }
    }
}

private struct ProjectCatalogRow: View {
    @Bindable var store: EditorStore
    let entry: ProjectCatalogEntry

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: "doc.badge.waveform")
                .font(.title2)
                .foregroundStyle(NotchPalette.accent)
                .frame(width: 32)

            Button {
                store.openCatalogEntry(entry)
            } label: {
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.name)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(entry.sourceDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(
                        entry.lastOpened.formatted(
                            date: .abbreviated,
                            time: .shortened
                        )
                    )
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Button {
                store.toggleConserved(entry)
            } label: {
                Image(systemName: entry.isConserved ? "pin.fill" : "pin")
            }
            .buttonStyle(.borderless)
            .help(entry.isConserved ? "Quitar de Conservados" : "Conservar proyecto")

            Button {
                store.revealCatalogEntry(entry)
            } label: {
                Image(systemName: "magnifyingglass")
            }
            .buttonStyle(.borderless)
            .help("Mostrar en Finder")

            Button {
                store.removeCatalogEntry(entry)
            } label: {
                Image(systemName: "xmark")
            }
            .buttonStyle(.borderless)
            .help("Quitar de la biblioteca")
        }
        .padding(.vertical, 8)
    }
}

private struct EmptyEditorView: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: "waveform.badge.plus")
                .font(.system(size: 42, weight: .light))
                .foregroundStyle(NotchPalette.accent)

            VStack(spacing: 5) {
                Text("Cargá un audio para comenzar")
                    .font(.title2.bold())
                Text("Pegá una dirección arriba o seleccioná un archivo de tu Mac.")
                    .foregroundStyle(.secondary)
            }

            Button(action: store.chooseLocalFile) {
                Label("Abrir archivo…", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .disabled(store.isImporting || store.isExporting)
        }
        .frame(maxWidth: .infinity, minHeight: 280)
        .background(
            LinearGradient(
                colors: [
                    NotchPalette.accent.opacity(0.045),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}

private struct SourceBar: View {
    @Bindable var store: EditorStore

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "link")
                .foregroundStyle(.secondary)
            TextField("Pegá una dirección de YouTube u otra fuente compatible", text: $store.sourceURL)
                .textFieldStyle(.plain)
                .disabled(store.isImporting || store.isExporting)
                .onSubmit(store.importRemoteSource)

            if store.isImporting {
                if let progress = store.importProgress {
                    ProgressView(value: progress)
                        .progressViewStyle(.linear)
                        .frame(width: 92)
                } else {
                    ProgressView()
                        .controlSize(.small)
                }
            }

            Button(importButtonTitle, action: store.importRemoteSource)
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.isImporting
                        || store.isExporting
                        || store.sourceURL.trimmingCharacters(in: .whitespaces).isEmpty
                )

            Button(action: store.chooseLocalFile) {
                Label("Abrir archivo", systemImage: "folder")
            }
            .buttonStyle(.bordered)
            .disabled(store.isImporting || store.isExporting)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 13)
    }

    private var importButtonTitle: String {
        guard store.isImporting else { return "Importar" }
        guard let progress = store.importProgress else { return "Importando…" }
        return "Importando \(Int(progress * 100))%"
    }
}

private struct EditorHeader: View {
    @Bindable var store: EditorStore

    var body: some View {
        HStack(spacing: 14) {
            Button(action: store.togglePlayback) {
                Image(systemName: store.isPlaying ? "pause.fill" : "play.fill")
                    .frame(width: 17, height: 17)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .help(store.isPlaying ? "Pausar" : "Reproducir")

            Text(Timecode.string(from: store.playhead))
                .font(.system(.title3, design: .monospaced, weight: .medium))
            Text("/ \(Timecode.string(from: store.source.duration, includeMilliseconds: false))")
                .foregroundStyle(.secondary)

            Spacer()

            Button(action: store.addRegionAtPlayhead) {
                Label("Nueva región", systemImage: "plus")
            }

            Image(systemName: "minus.magnifyingglass")
                .foregroundStyle(.secondary)
            Slider(value: $store.zoom, in: 1...8)
                .frame(width: 120)
            Image(systemName: "plus.magnifyingglass")
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 16)
    }
}

private struct ClipList: View {
    @Bindable var store: EditorStore

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Recortes")
                    .font(.title3.bold())
                Text("\(store.regions.count)")
                    .font(.caption.bold())
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(.quaternary, in: Capsule())

                Button(action: store.addRegionAtPlayhead) {
                    Label("Nuevo recorte", systemImage: "plus")
                }
                .buttonStyle(.bordered)
                .help("Crear un recorte en la posición actual")

                Spacer()

                Text("Nombre base")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField("Nombre del proyecto", text: $store.projectName)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 260)

                if store.isExporting {
                    ProgressView(value: store.exportProgress)
                        .progressViewStyle(.linear)
                        .frame(width: 80)
                }

                Button(action: store.chooseExportDirectory) {
                    Label(
                        (
                            store.exportDirectoryURL
                                ?? store.preferences.exportDirectoryURL
                        ).lastPathComponent,
                        systemImage: "folder"
                    )
                }
                .buttonStyle(.bordered)
                .disabled(store.isExporting)
                .help(
                    store.exportDirectoryURL?.path(percentEncoded: false)
                        ?? "Predeterminado: \(store.preferences.exportDirectoryURL.path(percentEncoded: false))"
                )

                Button(action: store.exportRegions) {
                    Label(exportButtonTitle, systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.borderedProminent)
                .disabled(
                    store.isExporting
                        || store.regions.allSatisfy { !$0.isEnabled }
                )
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 14)

            if store.regions.isEmpty {
                ContentUnavailableView(
                    "Todavía no hay recortes",
                    systemImage: "selection.pin.in.out",
                    description: Text("Creá una región desde la línea de tiempo o en la posición del cabezal.")
                )
                .frame(maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(store.regions.enumerated()), id: \.element.id) { index, region in
                            ClipRow(store: store, region: region, index: index)
                        }
                    }
                    .padding(.horizontal, 22)
                    .padding(.bottom, 16)
                }
            }
        }
        .frame(minHeight: 235, idealHeight: 290)
    }

    private var exportButtonTitle: String {
        if store.isExporting {
            return "Exportando \(Int(store.exportProgress * 100))%"
        }
        return "Exportar \(store.regions.filter(\.isEnabled).count)"
    }
}

private struct ClipRow: View {
    @Bindable var store: EditorStore
    let region: ClipRegion
    let index: Int

    private var isSelected: Bool {
        store.selectedRegionID == region.id
    }

    var body: some View {
        HStack(spacing: 12) {
            Toggle(
                "",
                isOn: Binding(
                    get: { region.isEnabled },
                    set: { value in
                        var copy = region
                        copy.isEnabled = value
                        store.updateRegion(copy)
                    }
                )
            )
            .labelsHidden()

            RoundedRectangle(cornerRadius: 2)
                .fill(NotchPalette.regionColors[region.colorIndex % NotchPalette.regionColors.count])
                .frame(width: 4, height: 38)

            Text(String(format: "%02d", index + 1))
                .font(.system(.body, design: .monospaced))
                .foregroundStyle(.secondary)

            TextField(
                "Nombre del recorte",
                text: Binding(
                    get: { region.name },
                    set: { value in
                        var copy = region
                        copy.name = value
                        store.updateRegion(copy)
                    }
                )
            )
            .textFieldStyle(.plain)
            .frame(minWidth: 170)

            TimeField(
                value: region.start,
                accessibilityLabel: "Inicio",
                onCommit: { store.setRegionBounds(id: region.id, start: $0) }
            )

            Image(systemName: "arrow.right")
                .foregroundStyle(.tertiary)

            TimeField(
                value: region.end,
                accessibilityLabel: "Fin",
                onCommit: { store.setRegionBounds(id: region.id, end: $0) }
            )

            Text(Timecode.string(from: region.duration, includeMilliseconds: false))
                .font(.caption.monospacedDigit())
                .foregroundStyle(.secondary)
                .frame(width: 55, alignment: .trailing)

            Spacer()

            Text(store.outputName(for: region, index: index))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .frame(maxWidth: 245, alignment: .trailing)

            Button {
                store.preview(region)
            } label: {
                Image(systemName: "play.fill")
            }
            .buttonStyle(.borderless)
            .help("Previsualizar recorte")

            Button(role: .destructive) {
                store.deleteRegion(region.id)
            } label: {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .help("Eliminar recorte")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
        .background(
            isSelected ? NotchPalette.accent.opacity(0.10) : Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 9)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 9)
                .stroke(isSelected ? NotchPalette.accent.opacity(0.55) : .clear)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            store.selectedRegionID = region.id
        }
    }

}

private struct TimeField: View {
    let value: TimeInterval
    let accessibilityLabel: String
    let onCommit: (TimeInterval) -> Void
    @State private var text: String
    @FocusState private var isFocused: Bool

    init(value: TimeInterval, accessibilityLabel: String, onCommit: @escaping (TimeInterval) -> Void) {
        self.value = value
        self.accessibilityLabel = accessibilityLabel
        self.onCommit = onCommit
        _text = State(initialValue: Timecode.string(from: value))
    }

    var body: some View {
        TextField(
            accessibilityLabel,
            text: $text
        )
        .font(.system(.body, design: .monospaced))
        .multilineTextAlignment(.center)
        .textFieldStyle(.roundedBorder)
        .frame(width: 94)
        .focused($isFocused)
        .onSubmit(commit)
        .onChange(of: isFocused) { wasFocused, isFocused in
            if wasFocused && !isFocused {
                commit()
            }
        }
        .onChange(of: value) { _, newValue in
            text = Timecode.string(from: newValue)
        }
        .accessibilityLabel(accessibilityLabel)
    }

    private func commit() {
        guard let seconds = Timecode.seconds(from: text) else {
            text = Timecode.string(from: value)
            NSSound.beep()
            return
        }
        onCommit(seconds)
    }
}

private struct StatusBar: View {
    @Bindable var store: EditorStore

    var body: some View {
        HStack {
            Circle()
                .fill(NotchPalette.accent)
                .frame(width: 7, height: 7)
            Text(store.statusMessage)
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Text(
                "\(store.preferences.outputFormat.displayName) · \(store.preferences.outputFormat.qualityDescription)"
            )
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
        .background(.bar)
    }
}
