import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @State private var cacheSize: Int64 = 0
    @State private var showsClearCacheConfirmation = false
    @State private var cacheMessage = ""

    var body: some View {
        Form {
            Section("Carpetas predeterminadas") {
                folderRow(
                    title: "Caché",
                    url: preferences.cacheDirectoryURL,
                    choose: preferences.chooseCacheDirectory
                )
                folderRow(
                    title: "Biblioteca",
                    url: preferences.libraryDirectoryURL,
                    choose: preferences.chooseLibraryDirectory
                )
                folderRow(
                    title: "Exportación",
                    url: preferences.exportDirectoryURL,
                    choose: preferences.chooseExportDirectory
                )
            }

            Section("Caché de medios") {
                HStack {
                    Text("Uso actual")
                    Spacer()
                    Text(ByteCountFormatter.string(
                        fromByteCount: cacheSize,
                        countStyle: .file
                    ))
                    .foregroundStyle(.secondary)
                    Button("Abrir") {
                        preferences.openDirectory(preferences.cacheDirectoryURL)
                    }
                    Button("Limpiar…", role: .destructive) {
                        showsClearCacheConfirmation = true
                    }
                }
                if !cacheMessage.isEmpty {
                    Text(cacheMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Exportación") {
                Picker("Formato de salida", selection: $preferences.outputFormat) {
                    ForEach(AudioOutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Picker("Nombres de archivos", selection: $preferences.namingConvention) {
                    ForEach(ExportNamingConvention.allCases) { convention in
                        Text(convention.displayName).tag(convention)
                    }
                }

                LabeledContent("Ejemplo") {
                    Text(
                        "\(preferences.namingConvention.example).\(preferences.outputFormat.fileExtension)"
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
        .formStyle(.grouped)
        .padding(8)
        .frame(width: 680, height: 500)
        .onAppear(perform: refreshCacheSize)
        .onChange(of: preferences.cacheDirectoryURL) {
            refreshCacheSize()
        }
        .alert(
            "¿Limpiar toda la caché?",
            isPresented: $showsClearCacheConfirmation
        ) {
            Button("Cancelar", role: .cancel) {}
            Button("Limpiar caché", role: .destructive) {
                clearCache()
            }
        } message: {
            Text("Los audios de YouTube deberán descargarse nuevamente. Los proyectos y recortes no se eliminarán.")
        }
    }

    @ViewBuilder
    private func folderRow(
        title: String,
        url: URL,
        choose: @escaping () -> Void
    ) -> some View {
        LabeledContent(title) {
            HStack {
                Text(url.path(percentEncoded: false))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 380, alignment: .trailing)
                Button("Abrir") {
                    preferences.openDirectory(url)
                }
                Button("Cambiar…", action: choose)
            }
        }
    }

    private func refreshCacheSize() {
        cacheSize = preferences.cacheSize()
    }

    private func clearCache() {
        do {
            try preferences.clearCache()
            cacheMessage = "Caché limpiada"
        } catch {
            cacheMessage = error.localizedDescription
        }
        refreshCacheSize()
    }
}
