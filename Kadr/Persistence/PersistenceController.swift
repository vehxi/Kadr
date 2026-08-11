import SwiftData

enum PersistenceController {
    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            Movie.self,
            Genre.self,
            SeriesSeason.self,
            SeriesEpisode.self
        ])
        let configuration = ModelConfiguration(
            "MyMovies",
            schema: schema,
            isStoredInMemoryOnly: inMemory
        )
        return try ModelContainer(for: schema, configurations: [configuration])
    }

    @MainActor
    static func migrateLegacyFavorites(in context: ModelContext) throws {
        let movies = try context.fetch(FetchDescriptor<Movie>())
        let didMigrate = movies.reduce(into: false) { result, movie in
            result = movie.migrateLegacyFavoriteIfNeeded() || result
        }
        if didMigrate {
            try context.save()
        }
    }
}
