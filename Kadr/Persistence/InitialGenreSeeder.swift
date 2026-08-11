import Foundation
import SwiftData

@MainActor
enum InitialGenreSeeder {
    private static let englishGenres = [
        "Action", "Drama", "Comedy", "Thriller", "Science Fiction",
        "Fantasy", "Horror", "Documentary", "Animation"
    ]

    private static let russianGenres = [
        "Боевик", "Драма", "Комедия", "Триллер", "Фантастика",
        "Фэнтези", "Ужасы", "Документальный", "Анимация"
    ]

    static func seedIfNeeded(context: ModelContext, language: AppLanguage) throws {
        var descriptor = FetchDescriptor<Genre>()
        descriptor.fetchLimit = 1
        guard try context.fetch(descriptor).isEmpty else { return }

        let usesRussian: Bool
        switch language {
        case .russian:
            usesRussian = true
        case .english:
            usesRussian = false
        case .system:
            usesRussian = Locale.preferredLanguages.first?.hasPrefix("ru") == true
        }

        for name in usesRussian ? russianGenres : englishGenres {
            context.insert(Genre(name: name))
        }
        try context.save()
    }
}
