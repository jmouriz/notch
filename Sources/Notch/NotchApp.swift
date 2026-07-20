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
            AboutCommands()

            CommandGroup(replacing: .newItem) {
                Button("Nuevo proyecto") {
                    store.resetProject()
                }
                .keyboardShortcut("n")

                Button("Abrir proyecto…") {
                    store.openProject()
                }
                .keyboardShortcut("o")

                Divider()

                Button("Abrir audio o video…") {
                    store.chooseLocalFile()
                }
                .keyboardShortcut("o", modifiers: [.command, .shift])
            }

            CommandGroup(replacing: .saveItem) {
                Button("Guardar proyecto") {
                    store.saveProject()
                }
                .keyboardShortcut("s")

                Button("Guardar proyecto como…") {
                    store.saveProjectAs()
                }
                .keyboardShortcut("s", modifiers: [.command, .shift])
            }

            CommandMenu("Región") {
                Button("Nueva región en el cabezal") {
                    store.addRegionAtPlayhead()
                }
                .keyboardShortcut("r")

                Button("Previsualizar región seleccionada") {
                    store.previewSelectedRegion()
                }
                .keyboardShortcut(.space, modifiers: [])
            }
        }

        Settings {
            SettingsView(preferences: store.preferences)
        }

        Window("Acerca de Notch", id: "about") {
            AboutView()
        }
        .windowResizability(.contentSize)
        .defaultPosition(.center)
    }
}
