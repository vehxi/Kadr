import Foundation
import SwiftData
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@MainActor
struct CountryPersistenceTests {
    @Test("A library created before countries migrates without losing records or relationships")
    func migrateLegacyLibrary() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-country-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let url = directory.appendingPathComponent("MyMovies.store")
        let id = UUID()
        try writeLegacyLibrary(at: url, id: id)

        let schema = Schema([Movie.self, Genre.self, SeriesSeason.self, SeriesEpisode.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("MyMovies", schema: schema, url: url)])
        let movie = try #require(container.mainContext.fetch(FetchDescriptor<Movie>()).first)
        #expect(movie.id == id)
        #expect(movie.title == "Legacy series")
        #expect(movie.countryCodes.isEmpty)
        #expect(movie.rating == 4)
        #expect(movie.isFavorite)
        #expect(movie.genres.first?.name == "Drama")
        #expect(movie.watchedEpisodeCount == 1)
        #expect(movie.coverFilename == "existing-cover.jpg")
        movie.countryCodes = ["JP", "DE"]
        try container.mainContext.save()
        let freshContext = ModelContext(container)
        #expect(try freshContext.fetch(FetchDescriptor<Movie>()).first?.countryCodes == ["DE", "JP"])
    }

    private func writeLegacyLibrary(at url: URL, id: UUID) throws {
        let schema = Schema([BeforeCountries.Movie.self, BeforeCountries.Genre.self, BeforeCountries.SeriesSeason.self, BeforeCountries.SeriesEpisode.self])
        let container = try ModelContainer(for: schema, configurations: [ModelConfiguration("MyMovies", schema: schema, url: url)])
        let movie = BeforeCountries.Movie(id: id)
        container.mainContext.insert(movie)
        let genre = BeforeCountries.Genre()
        container.mainContext.insert(genre)
        movie.genres = [genre]
        let season = BeforeCountries.SeriesSeason()
        container.mainContext.insert(season)
        season.movie = movie
        let episode = BeforeCountries.SeriesEpisode()
        container.mainContext.insert(episode)
        episode.season = season
        season.episodes = [episode]
        movie.seasons = [season]
        try container.mainContext.save()
    }
}

// Frozen pre-country storage schema. Keep entity/property names, types and delete rules intact.
private enum BeforeCountries {
    @Model final class Movie {
        @Attribute(.unique) var id: UUID
        var title: String
        var normalizedTitle: String
        var mediaKindRawValue: String = "movie"
        var releaseYear: Int?
        var releaseEndYear: Int? = nil
        var statusRawValue: String
        var favoriteFlag: Bool = false
        var rating: Int?
        var synopsis: String
        var coverFilename: String?
        var tierRawValue: String?
        var createdAt: Date
        var updatedAt: Date
        @Relationship(deleteRule: .nullify, inverse: \Genre.movies) var genres: [Genre]
        @Relationship(deleteRule: .cascade, inverse: \SeriesSeason.movie) var seasons: [SeriesSeason]

        init(id: UUID) {
            self.id = id
            title = "Legacy series"
            normalizedTitle = "legacy series"
            mediaKindRawValue = "series"
            releaseYear = 2020
            releaseEndYear = 2021
            statusRawValue = "watched"
            favoriteFlag = true
            rating = 4
            synopsis = "Preserved synopsis"
            coverFilename = "existing-cover.jpg"
            tierRawValue = nil
            createdAt = .now
            updatedAt = .now
            genres = []
            seasons = []
        }
    }

    @Model final class Genre {
        @Attribute(.unique) var id: UUID
        var name: String
        @Attribute(.unique) var normalizedName: String
        var catalogID: String?
        var createdAt: Date
        var movies: [Movie]
        init() {
            id = UUID(); name = "Drama"; normalizedName = "drama"
            catalogID = nil; createdAt = .now; movies = []
        }
    }

    @Model final class SeriesSeason {
        @Attribute(.unique) var id: UUID
        var number: Int
        var movie: Movie?
        @Relationship(deleteRule: .cascade, inverse: \SeriesEpisode.season) var episodes: [SeriesEpisode]
        init() { id = UUID(); number = 1; movie = nil; episodes = [] }
    }

    @Model final class SeriesEpisode {
        @Attribute(.unique) var id: UUID
        var number: Int
        var title: String
        var isWatched: Bool
        var watchedAt: Date?
        var season: SeriesSeason?
        init() {
            id = UUID(); number = 1; title = "Pilot"; isWatched = true
            watchedAt = .now; season = nil
        }
    }
}
