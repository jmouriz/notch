import SwiftUI

@main
struct NotchApp: App {
    @State private var store = EditorStore()

    var body: some Scene {
        WindowGroup {
            ContentView(store: store)
                .frame(minWidth: 1_080, minHeight: 700)
                .onOpenURL { url in
                    store.openProject(at: url)
                }
        }
        .defaultSize(width: 1_280, height: 820)
        .windowResizability(.contentMinSize)
        .commands {
            AboutCommands(preferences: store.preferences)

            CommandGroup(replacing: .newItem) {
                Button(t("menu.new_project")) {
                    store.resetProject()
                }
                .keyboardShortcut("n")

                Button(t("menu.open_project")) {
                    store.openProject()
                }
                .keyboardShortcut("o")

                Divider()

                Button(t("menu.open_media")) {
                    store.chooseLocalFile()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button(t("menu.save_project")) {
                    store.saveProject()
                }
                .keyboardShortcut("s")

                Button(t("menu.save_project_as")) {
                    store.saveProjectAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu(t("menu.region")) {
                Button(t("menu.new_region")) {
                    store.addRegionAtPlayhead()
                }
                .keyboardShortcut("r")

                Button(t("menu.preview_region")) {
                    store.previewSelectedRegion()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }

        Settings {
            SettingsView(preferences: store.preferences)
        }

        Window("Notch", id: "about") {
            AboutView(preferences: store.preferences)
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }

    private func t(_ key: String) -> String {
        L10n.string(key, language: store.preferences.language)
    }
}
