import Foundation

enum ProductionCountries {
    static let codes = Set(Locale.Region.isoRegions.map(\.identifier).filter { $0.count == 2 })

    static func normalized(_ codes: [String]) -> [String] {
        Set(codes.map { $0.trimmingCharacters(in: .whitespacesAndNewlines).uppercased() })
            .filter { Self.codes.contains($0) }.sorted()
    }

    static func name(for code: String, locale: Locale) -> String {
        locale.localizedString(forRegionCode: code) ?? code
    }

    static func sortedCodes(locale: Locale) -> [String] {
        codes.sorted {
            name(for: $0, locale: locale).compare(name(for: $1, locale: locale), locale: locale) == .orderedAscending
        }
    }
}
