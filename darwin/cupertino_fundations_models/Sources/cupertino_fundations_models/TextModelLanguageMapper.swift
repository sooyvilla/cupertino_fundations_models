import Foundation

@available(iOS 26.0, macOS 26.0, *)
enum TextModelLanguageMapper {
    static func rows(_ languages: Set<Locale.Language>, displayLocale: Locale = .current) -> [[String: Any]] {
        languages.sorted { $0.minimalIdentifier < $1.minimalIdentifier }.map { language in
            let identifier = language.minimalIdentifier.replacingOccurrences(of: "_", with: "-")
            let displayName = displayLocale.localizedString(forIdentifier: identifier) ?? identifier
            let nativeName = Locale(identifier: identifier).localizedString(forIdentifier: identifier) ?? displayName
            return ["identifier": identifier, "languageCode": language.languageCode?.identifier ?? identifier,
                    "displayName": displayName, "nativeDisplayName": nativeName]
        }
    }
}
