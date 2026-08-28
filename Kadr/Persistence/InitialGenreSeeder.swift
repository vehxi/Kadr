import Foundation
import SwiftData

@MainActor
enum InitialGenreSeeder {
    private static let catalogVersion = 1
    private static let catalogVersionKey = "genreCatalogVersion"

    static func seedIfNeeded(
        context: ModelContext,
        language: AppLanguage,
        defaults: UserDefaults = .standard
    ) throws {
        let genres = try context.fetch(FetchDescriptor<Genre>())
        guard genres.isEmpty || defaults.integer(forKey: catalogVersionKey) < catalogVersion else {
            return
        }

        let usesRussian: Bool
        switch language {
        case .russian:
            usesRussian = true
        case .english:
            usesRussian = false
        case .system:
            usesRussian = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        }

        for genre in genres where genre.catalogID == nil {
            genre.catalogID = GenreCatalog.definition(matching: genre.name)?.id
        }

        let existingCatalogIDs = Set(genres.compactMap(\.catalogID))
        let locale = Locale(identifier: usesRussian ? "ru" : "en")
        for definition in GenreCatalog.definitions where !existingCatalogIDs.contains(definition.id) {
            context.insert(
                Genre(
                    name: definition.name(for: locale),
                    catalogID: definition.id
                )
            )
        }
        try context.save()
        defaults.set(catalogVersion, forKey: catalogVersionKey)
    }
}
