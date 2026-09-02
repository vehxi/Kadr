import Foundation
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@Suite("Library backup decoding")
struct LibraryBackupServiceTests {
    @Test("Decodes a valid archive")
    @MainActor
    func decodesValidArchive() throws {
        let original = LibraryBackupFixtures.validArchive()
        let decoded = try LibraryBackupService.decode(
            data: LibraryBackupFixtures.encoded(original)
        )

        #expect(decoded.formatVersion == LibraryBackupArchive.currentFormatVersion)
        #expect(decoded.createdAt == LibraryBackupFixtures.timestamp)
        #expect(decoded.movieCount == 1)
        #expect(decoded.seriesCount == 1)
        #expect(decoded.coverCount == 1)

        let genre = try #require(decoded.genres.first)
        #expect(genre.name == "Drama")
        #expect(genre.catalogID == "drama")

        let movie = try #require(decoded.movies.first)
        #expect(movie.title == "Severance")
        #expect(movie.mediaKindRawValue == MediaKind.series.rawValue)
        #expect(movie.statusRawValue == ViewingStatus.watching.rawValue)
        #expect(movie.rating == 5)
        #expect(movie.tierRawValue == MovieTier.s.rawValue)
        #expect(movie.genreIDs == [genre.id])
        #expect(movie.coverData == Data([0x01, 0x02, 0x03]))

        let season = try #require(movie.seasons.first)
        #expect(season.number == 1)
        let episode = try #require(season.episodes.first)
        #expect(episode.number == 1)
        #expect(episode.title == "Pilot")
        #expect(episode.isWatched)
        #expect(episode.watchedAt == LibraryBackupFixtures.timestamp)
    }

    @Test("Rejects data that is not a backup archive")
    @MainActor
    func rejectsInvalidFile() {
        expectDecodeError(.invalidFile, data: Data("not a plist".utf8))
    }

    @Test("Rejects an unsupported format version")
    @MainActor
    func rejectsUnsupportedVersion() throws {
        let archive = LibraryBackupFixtures.archive(
            formatVersion: LibraryBackupArchive.currentFormatVersion + 1
        )

        try expectDecodeError(.unsupportedVersion, archive: archive)
    }

    @Test("Rejects duplicate genre UUIDs")
    @MainActor
    func rejectsDuplicateGenreIDs() throws {
        let id = UUID()
        let archive = LibraryBackupFixtures.archive(
            genres: [
                LibraryBackupFixtures.genre(id: id, name: "Drama"),
                LibraryBackupFixtures.genre(id: id, name: "Comedy")
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects duplicate movie UUIDs")
    @MainActor
    func rejectsDuplicateMovieIDs() throws {
        let id = UUID()
        let archive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(id: id, title: "Arrival"),
                LibraryBackupFixtures.movie(id: id, title: "Dune")
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects duplicate season UUIDs across movies")
    @MainActor
    func rejectsDuplicateSeasonIDs() throws {
        let seasonID = UUID()
        let archive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    id: UUID(),
                    seasons: [LibraryBackupFixtures.season(id: seasonID)]
                ),
                LibraryBackupFixtures.movie(
                    id: UUID(),
                    seasons: [LibraryBackupFixtures.season(id: seasonID)]
                )
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects duplicate episode UUIDs across seasons")
    @MainActor
    func rejectsDuplicateEpisodeIDs() throws {
        let episodeID = UUID()
        let archive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    seasons: [
                        LibraryBackupFixtures.season(
                            number: 1,
                            episodes: [LibraryBackupFixtures.episode(id: episodeID)]
                        ),
                        LibraryBackupFixtures.season(
                            number: 2,
                            episodes: [LibraryBackupFixtures.episode(id: episodeID)]
                        )
                    ]
                )
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects a reference to an unknown genre")
    @MainActor
    func rejectsUnknownGenreReference() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [LibraryBackupFixtures.movie(genreIDs: [UUID()])]
        )

        try expectDecodeError(.invalidReferences, archive: archive)
    }

    @Test("Rejects duplicate genre references on one movie")
    @MainActor
    func rejectsDuplicateGenreReferences() throws {
        let genreID = UUID()
        let archive = LibraryBackupFixtures.archive(
            genres: [LibraryBackupFixtures.genre(id: genreID)],
            movies: [LibraryBackupFixtures.movie(genreIDs: [genreID, genreID])]
        )

        try expectDecodeError(.invalidReferences, archive: archive)
    }

    @Test("Rejects a rating outside the supported range")
    @MainActor
    func rejectsInvalidRating() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [LibraryBackupFixtures.movie(rating: 6)]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects an unknown viewing status")
    @MainActor
    func rejectsInvalidStatus() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [LibraryBackupFixtures.movie(statusRawValue: "paused")]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects an unknown tier")
    @MainActor
    func rejectsInvalidTier() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [LibraryBackupFixtures.movie(tierRawValue: "legendary")]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects repeated season numbers in one series")
    @MainActor
    func rejectsRepeatedSeasonNumbers() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    seasons: [
                        LibraryBackupFixtures.season(number: 1),
                        LibraryBackupFixtures.season(number: 1)
                    ]
                )
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects repeated episode numbers in one season")
    @MainActor
    func rejectsRepeatedEpisodeNumbers() throws {
        let archive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    seasons: [
                        LibraryBackupFixtures.season(
                            episodes: [
                                LibraryBackupFixtures.episode(number: 1),
                                LibraryBackupFixtures.episode(number: 1)
                            ]
                        )
                    ]
                )
            ]
        )

        try expectDecodeError(.invalidValues, archive: archive)
    }

    @Test("Rejects nonpositive season and episode numbers", arguments: [0, -1])
    @MainActor
    func rejectsNonpositiveNumbers(number: Int) throws {
        let seasonArchive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    seasons: [LibraryBackupFixtures.season(number: number)]
                )
            ]
        )
        let episodeArchive = LibraryBackupFixtures.archive(
            movies: [
                LibraryBackupFixtures.movie(
                    seasons: [
                        LibraryBackupFixtures.season(
                            episodes: [LibraryBackupFixtures.episode(number: number)]
                        )
                    ]
                )
            ]
        )

        try expectDecodeError(.invalidValues, archive: seasonArchive)
        try expectDecodeError(.invalidValues, archive: episodeArchive)
    }
}

private enum ExpectedBackupError {
    case invalidFile
    case unsupportedVersion
    case invalidReferences
    case invalidValues

    func matches(_ error: LibraryBackupError) -> Bool {
        switch (self, error) {
        case (.invalidFile, .invalidFile),
             (.unsupportedVersion, .unsupportedVersion),
             (.invalidReferences, .invalidReferences),
             (.invalidValues, .invalidValues):
            true
        default:
            false
        }
    }
}

@MainActor
private func expectDecodeError(
    _ expectedError: ExpectedBackupError,
    archive: LibraryBackupArchive
) throws {
    expectDecodeError(expectedError, data: try LibraryBackupFixtures.encoded(archive))
}

@MainActor
private func expectDecodeError(
    _ expectedError: ExpectedBackupError,
    data: Data
) {
    do {
        _ = try LibraryBackupService.decode(data: data)
        Issue.record("Expected backup decoding to fail")
    } catch let error as LibraryBackupError {
        #expect(expectedError.matches(error))
    } catch {
        Issue.record("Unexpected error type: \(error)")
    }
}
