import Foundation

enum TextNormalizer {
    static func displayName(_ value: String) -> String {
        value
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    static func normalize(_ value: String) -> String {
        displayName(value).folding(
            options: [.caseInsensitive],
            locale: Locale(identifier: "en_US_POSIX")
        )
    }
}
