import Foundation

enum AppLocalization {
    static func string(_ key: String, locale: Locale) -> String {
        let languageCode = locale.language.languageCode?.identifier ?? "en"
        guard let path = Bundle.main.path(
            forResource: languageCode,
            ofType: "lproj"
        ),
        let localizedBundle = Bundle(path: path)
        else {
            return key
        }

        return localizedBundle.localizedString(
            forKey: key,
            value: key,
            table: nil
        )
    }
}
