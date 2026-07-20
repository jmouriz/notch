import Foundation
import Testing
@testable import Notch

@Test func explicitLanguagesLoadTheirOwnCatalogs() {
    #expect(L10n.string("editor.import", language: .english) == "Import")
    #expect(L10n.string("editor.import", language: .spanish) == "Importar")
    #expect(L10n.string("editor.import", language: .portuguese) == "Importar")
}

@Test func localizedStringsInterpolateValues() {
    #expect(
        L10n.string("clips.export_count", language: .english, 3)
            == "Export 3"
    )
    #expect(
        L10n.string("clips.export_count", language: .spanish, 3)
            == "Exportar 3"
    )
    #expect(
        L10n.string("clips.export_count", language: .portuguese, 3)
            == "Exportar 3"
    )
}

@Test func systemLanguageAlwaysResolvesToASupportedCatalog() {
    #expect(["en", "es", "pt"].contains(AppLanguage.system.localizationCode))
}

@MainActor
@Test func changingLanguageUpdatesTheIdleEditorImmediately() throws {
    let suiteName = "NotchTests.Localization.\(UUID().uuidString)"
    let defaults = try #require(UserDefaults(suiteName: suiteName))
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let store = EditorStore(userDefaults: defaults)
    store.preferences.language = .english
    store.languageDidChange()
    #expect(store.projectName == "My clips")
    #expect(store.statusMessage == "Ready to edit")

    store.preferences.language = .spanish
    store.languageDidChange()
    #expect(store.projectName == "Mis recortes")
    #expect(store.statusMessage == "Listo para editar")
}
