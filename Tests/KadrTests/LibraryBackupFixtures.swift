import Foundation

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

enum LibraryBackupFixtures {
    static let timestamp = Date(timeIntervalSince1970: 1_700_000_000)

    static func archive(
        formatVersion: Int = LibraryBackupArchive.currentFormatVersion,
        genres: [LibraryBackupArchive.GenreRecord] = [],
        movies: [LibraryBackupArchive.MovieRecord] = []
    ) -> LibraryBackupArchive {
        LibraryBackupArchive(
            formatVersion: formatVersion,
            createdAt: timestamp,
            genres: genres,
            movies: movies
        )
    }

    static func validArchive() -> LibraryBackupArchive {
        let genreID = UUID()
        let season = season(
            number: 1,
            episodes: [episode(number: 1, title: "Pilot", isWatched: true)]
        )
        let movie = movie(
            title: "Severance",
            mediaKindRawValue: MediaKind.series.rawValue,
            releaseYear: 2022,
            statusRawValue: ViewingStatus.watching.rawValue,
            isFavorite: true,
            rating: 5,
            synopsis: "A series synopsis",
            tierRawValue: MovieTier.s.rawValue,
            genreIDs: [genreID],
            seasons: [season],
            coverData: Data([0x01, 0x02, 0x03])
        )

        return archive(
            genres: [genre(id: genreID, name: "Drama", catalogID: "drama")],
            movies: [movie]
        )
    }

    static func genre(
        id: UUID = UUID(),
        name: String = "Drama",
        catalogID: String? = "drama"
    ) -> LibraryBackupArchive.GenreRecord {
        LibraryBackupArchive.GenreRecord(
            id: id,
            name: name,
            catalogID: catalogID,
            createdAt: timestamp
        )
    }

    static func movie(
        id: UUID = UUID(),
        title: String = "Arrival",
        mediaKindRawValue: String = MediaKind.movie.rawValue,
        releaseYear: Int? = 2016,
        releaseEndYear: Int? = nil,
        statusRawValue: String = ViewingStatus.watched.rawValue,
        isFavorite: Bool = false,
        rating: Int? = 4,
        synopsis: String = "A movie synopsis",
        tierRawValue: String? = nil,
        genreIDs: [UUID] = [],
        seasons: [LibraryBackupArchive.SeasonRecord] = [],
        coverData: Data? = nil
    ) -> LibraryBackupArchive.MovieRecord {
        LibraryBackupArchive.MovieRecord(
            id: id,
            title: title,
            mediaKindRawValue: mediaKindRawValue,
            releaseYear: releaseYear,
            releaseEndYear: releaseEndYear,
            statusRawValue: statusRawValue,
            isFavorite: isFavorite,
            rating: rating,
            synopsis: synopsis,
            tierRawValue: tierRawValue,
            createdAt: timestamp,
            updatedAt: timestamp,
            genreIDs: genreIDs,
            seasons: seasons,
            coverData: coverData
        )
    }

    static func season(
        id: UUID = UUID(),
        number: Int = 1,
        episodes: [LibraryBackupArchive.EpisodeRecord] = []
    ) -> LibraryBackupArchive.SeasonRecord {
        LibraryBackupArchive.SeasonRecord(
            id: id,
            number: number,
            episodes: episodes
        )
    }

    static func episode(
        id: UUID = UUID(),
        number: Int = 1,
        title: String = "",
        isWatched: Bool = false
    ) -> LibraryBackupArchive.EpisodeRecord {
        LibraryBackupArchive.EpisodeRecord(
            id: id,
            number: number,
            title: title,
            isWatched: isWatched,
            watchedAt: isWatched ? timestamp : nil
        )
    }

    static func encoded(_ archive: LibraryBackupArchive) throws -> Data {
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try encoder.encode(archive)
    }
}
