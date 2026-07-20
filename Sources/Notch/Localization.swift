import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable, Sendable {
    case system
    case english
    case spanish
    case portuguese

    var id: String { rawValue }

    var localizationCode: String {
        switch self {
        case .system:
            let preferred = Locale.preferredLanguages.first?
                .lowercased() ?? "en"
            if preferred.hasPrefix("es") { return "es" }
            if preferred.hasPrefix("pt") { return "pt" }
            return "en"
        case .english:
            return "en"
        case .spanish:
            return "es"
        case .portuguese:
            return "pt"
        }
    }

    var locale: Locale {
        Locale(identifier: localizationCode)
    }
}

enum L10n {
    static let languageDefaultsKey = "NotchPreferences.language"

    static func string(
        _ key: String,
        language: AppLanguage? = nil,
        _ arguments: CVarArg...
    ) -> String {
        let selected = language ?? storedLanguage()
        let code = selected.localizationCode
        let bundle = localizedBundle(for: code)
        let format = bundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
        guard !arguments.isEmpty else { return format }
        return String(
            format: format,
            locale: selected.locale,
            arguments: arguments
        )
    }

    private static func storedLanguage() -> AppLanguage {
        AppLanguage(
            rawValue: UserDefaults.standard.string(
                forKey: languageDefaultsKey
            ) ?? ""
        ) ?? .system
    }

    private static func localizedBundle(for code: String) -> Bundle {
        guard let path = Bundle.module.path(
            forResource: code,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else {
            return Bundle.module
        }
        return bundle
    }
}
