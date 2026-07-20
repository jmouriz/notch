import AppKit
import SwiftUI

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow
    let preferences: AppPreferences

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button(L10n.string("about.menu", language: preferences.language)) {
                openWindow(id: "about")
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var preferences: AppPreferences

    private var version: String {
        Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "0.1.0"
    }

    var body: some View {
        VStack(spacing: 16) {
            Image(nsImage: NSApplication.shared.applicationIconImage)
                .resizable()
                .frame(width: 104, height: 104)

            VStack(spacing: 4) {
                Text("Notch")
                    .font(.system(size: 28, weight: .bold))
                Text(t("about.version", version))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 5) {
                Text("© 2026 Juan Manuel Mouriz")
                Text(t("about.license"))
                Link(
                    "github.com/jmouriz/notch",
                    destination: URL(string: "https://github.com/jmouriz/notch")!
                )
            }

            Divider()

            VStack(spacing: 7) {
                Text(t("about.third_party"))
                    .font(.headline)
                Text("yt-dlp — The Unlicense")
                Text("LAME — GNU LGPL 2.0")
                Text(t("about.ffmpeg"))
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Button(t("common.close")) {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(width: 440)
    }

    private func t(_ key: String, _ arguments: CVarArg...) -> String {
        let format = L10n.string(key, language: preferences.language)
        guard !arguments.isEmpty else { return format }
        return String(
            format: format,
            locale: preferences.language.locale,
            arguments: arguments
        )
    }
}
