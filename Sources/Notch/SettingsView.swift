import SwiftUI

struct SettingsView: View {
    @Bindable var preferences: AppPreferences
    @State private var cacheSize: Int64 = 0
    @State private var showsClearCacheConfirmation = false
    @State private var cacheMessage = ""

    var body: some View {
        Form {
            Section(t("settings.general")) {
                Picker(t("settings.language"), selection: $preferences.language) {
                    Text(t("language.system")).tag(AppLanguage.system)
                    Text(t("language.english")).tag(AppLanguage.english)
                    Text(t("language.spanish")).tag(AppLanguage.spanish)
                    Text(t("language.portuguese")).tag(AppLanguage.portuguese)
                }
            }

            Section(t("settings.default_folders")) {
                folderRow(
                    title: t("settings.cache"),
                    url: preferences.cacheDirectoryURL,
                    choose: preferences.chooseCacheDirectory
                )
                folderRow(
                    title: t("settings.library"),
                    url: preferences.libraryDirectoryURL,
                    choose: preferences.chooseLibraryDirectory
                )
                folderRow(
                    title: t("settings.export"),
                    url: preferences.exportDirectoryURL,
                    choose: preferences.chooseExportDirectory
                )
            }

            Section(t("settings.media_cache")) {
                HStack {
                    Text(t("settings.current_usage"))
                    Spacer()
                    Text(ByteCountFormatter.string(
                        fromByteCount: cacheSize,
                        countStyle: .file
                    ))
                    .foregroundStyle(.secondary)
                    Button(t("settings.open")) {
                        preferences.openDirectory(preferences.cacheDirectoryURL)
                    }
                    Button(t("settings.clear"), role: .destructive) {
                        showsClearCacheConfirmation = true
                    }
                }
                if !cacheMessage.isEmpty {
                    Text(cacheMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section(t("settings.export")) {
                Picker(t("settings.output_format"), selection: $preferences.outputFormat) {
                    ForEach(AudioOutputFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }

                Picker(t("settings.file_names"), selection: $preferences.namingConvention) {
                    ForEach(ExportNamingConvention.allCases) { convention in
                        Text(convention.displayName).tag(convention)
                    }
                }

                LabeledContent(t("settings.example")) {
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
            t("settings.clear_cache_title"),
            isPresented: $showsClearCacheConfirmation
        ) {
            Button(t("settings.cancel"), role: .cancel) {}
            Button(t("settings.clear_cache"), role: .destructive) {
                clearCache()
            }
        } message: {
            Text(t("settings.clear_cache_message"))
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
                Button(t("settings.open")) {
                    preferences.openDirectory(url)
                }
                Button(t("settings.change"), action: choose)
            }
        }
    }

    private func refreshCacheSize() {
        cacheSize = preferences.cacheSize()
    }

    private func clearCache() {
        do {
            try preferences.clearCache()
            cacheMessage = t("settings.cache_cleared")
        } catch {
            cacheMessage = error.localizedDescription
        }
        refreshCacheSize()
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: preferences.language)
    }
}
