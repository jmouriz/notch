import AppKit
import SwiftUI

struct AboutCommands: Commands {
    @Environment(\.openWindow) private var openWindow

    var body: some Commands {
        CommandGroup(replacing: .appInfo) {
            Button("Acerca de Notch") {
                openWindow(id: "about")
            }
        }
    }
}

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

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
                Text("Versión \(version)")
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 5) {
                Text("© 2026 Juan Manuel Mouriz")
                Text("Publicado bajo la licencia MIT")
                Link(
                    "github.com/jmouriz/notch",
                    destination: URL(string: "https://github.com/jmouriz/notch")!
                )
            }

            Divider()

            VStack(spacing: 7) {
                Text("Componentes de terceros")
                    .font(.headline)
                Text("yt-dlp — The Unlicense")
                Text("LAME — GNU LGPL 2.0")
                Text("FFmpeg no está incluido en esta versión.")
                    .foregroundStyle(.secondary)
            }
            .font(.caption)

            Button("Cerrar") {
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
        }
        .multilineTextAlignment(.center)
        .padding(28)
        .frame(width: 440)
    }
}
