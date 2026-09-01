import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

extension UTType {
    static let kadrBackup = UTType(
        exportedAs: "app.kadr.backup",
        conformingTo: .data
    )
}

struct LibraryBackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.kadrBackup] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents else {
            throw LibraryBackupError.invalidFile
        }
        self.data = data
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct LibraryBackupArchive: Codable {
    static let currentFormatVersion = 1

    let formatVersion: Int
    let createdAt: Date
    let genres: [GenreRecord]
    let movies: [MovieRecord]

    var movieCount: Int { movies.count }
    var seriesCount: Int { movies.lazy.filter { $0.mediaKindRawValue == MediaKind.series.rawValue }.count }
    var coverCount: Int { movies.lazy.compactMap(\.coverData).count }

    struct GenreRecord: Codable {
        let id: UUID
        let name: String
        let catalogID: String?
        let createdAt: Date
    }

    struct MovieRecord: Codable {
        let id: UUID
        let title: String
        let mediaKindRawValue: String
        let releaseYear: Int?
        let releaseEndYear: Int?
        let statusRawValue: String
        let isFavorite: Bool
        let rating: Int?
        let synopsis: String
        let tierRawValue: String?
        let createdAt: Date
        let updatedAt: Date
        let genreIDs: [UUID]
        let seasons: [SeasonRecord]
        let coverData: Data?
    }

    struct SeasonRecord: Codable {
        let id: UUID
        let number: Int
        let episodes: [EpisodeRecord]
    }

    struct EpisodeRecord: Codable {
        let id: UUID
        let number: Int
        let title: String
        let isWatched: Bool
        let watchedAt: Date?
    }
}

enum LibraryBackupError: LocalizedError {
    case invalidFile
    case unsupportedVersion
    case invalidReferences
    case invalidValues

    var errorDescription: String? {
        switch self {
        case .invalidFile:
            String(localized: "The selected file is not a valid Kadr backup.")
        case .unsupportedVersion:
            String(localized: "This backup was created by an unsupported version of Kadr.")
        case .invalidReferences, .invalidValues:
            String(localized: "The backup is damaged and cannot be restored safely.")
        }
    }
}

@MainActor
enum LibraryBackupService {
    static func makeDocument(context: ModelContext) async throws -> LibraryBackupDocument {
        let archive = try await makeArchive(context: context)
        let encoder = PropertyListEncoder()
        encoder.outputFormat = .binary
        return try LibraryBackupDocument(data: encoder.encode(archive))
    }

    static func decode(data: Data) throws -> LibraryBackupArchive {
        let archive: LibraryBackupArchive
        do {
            archive = try PropertyListDecoder().decode(LibraryBackupArchive.self, from: data)
        } catch {
            throw LibraryBackupError.invalidFile
        }
        try validate(archive)
        return archive
    }

    static func restore(_ archive: LibraryBackupArchive, context: ModelContext) async throws {
        try validate(archive)

        var restoredCoverFilenames: [UUID: String] = [:]
        do {
            for movie in archive.movies {
                guard let coverData = movie.coverData else { continue }
                restoredCoverFilenames[movie.id] = try await CoverStore.shared.write(coverData)
            }

            try context.transaction {
                try deleteLibraryModels(context: context)

                var genresByID: [UUID: Genre] = [:]
                for record in archive.genres {
                    let genre = Genre(
                        id: record.id,
                        name: record.name,
                        catalogID: record.catalogID,
                        createdAt: record.createdAt
                    )
                    context.insert(genre)
                    genresByID[record.id] = genre
                }

                for record in archive.movies {
                    let movie = Movie(
                        id: record.id,
                        title: record.title,
                        mediaKind: MediaKind(rawValue: record.mediaKindRawValue) ?? .movie,
                        releaseYear: record.releaseYear,
                        releaseEndYear: record.releaseEndYear,
                        status: ViewingStatus(rawValue: record.statusRawValue) ?? .wantToWatch,
                        isFavorite: record.isFavorite,
                        rating: record.rating,
                        synopsis: record.synopsis,
                        coverFilename: restoredCoverFilenames[record.id],
                        tier: record.tierRawValue.flatMap(MovieTier.init(rawValue:)),
                        createdAt: record.createdAt,
                        updatedAt: record.updatedAt,
                        genres: record.genreIDs.compactMap { genresByID[$0] }
                    )
                    movie.seasons = record.seasons.map { seasonRecord in
                        let season = SeriesSeason(
                            id: seasonRecord.id,
                            number: seasonRecord.number,
                            movie: movie
                        )
                        season.episodes = seasonRecord.episodes.map { episodeRecord in
                            SeriesEpisode(
                                id: episodeRecord.id,
                                number: episodeRecord.number,
                                title: episodeRecord.title,
                                isWatched: episodeRecord.isWatched,
                                watchedAt: episodeRecord.watchedAt,
                                season: season
                            )
                        }
                        return season
                    }
                    context.insert(movie)
                }
            }
        } catch {
            context.rollback()
            for filename in restoredCoverFilenames.values {
                try? await CoverStore.shared.delete(filename: filename)
            }
            throw error
        }

        let referencedFilenames = Set(restoredCoverFilenames.values)
        try? await CoverStore.shared.removeOrphans(referencedFilenames: referencedFilenames)
    }

    static func reset(
        context: ModelContext,
        language: AppLanguage
    ) async throws {
        try context.transaction {
            try deleteLibraryModels(context: context)
        }

        try? await CoverStore.shared.removeOrphans(referencedFilenames: [])
        try InitialGenreSeeder.seedIfNeeded(context: context, language: language)
    }

    private static func makeArchive(context: ModelContext) async throws -> LibraryBackupArchive {
        let genres = try context.fetch(FetchDescriptor<Genre>())
            .sorted { $0.id.uuidString < $1.id.uuidString }
        let movies = try context.fetch(FetchDescriptor<Movie>())
            .sorted { $0.id.uuidString < $1.id.uuidString }

        var movieRecords: [LibraryBackupArchive.MovieRecord] = []
        movieRecords.reserveCapacity(movies.count)

        for movie in movies {
            let coverData = try await CoverStore.shared.data(for: movie.coverFilename)
            movieRecords.append(
                LibraryBackupArchive.MovieRecord(
                    id: movie.id,
                    title: movie.title,
                    mediaKindRawValue: movie.mediaKindRawValue,
                    releaseYear: movie.releaseYear,
                    releaseEndYear: movie.releaseEndYear,
                    statusRawValue: movie.statusRawValue,
                    isFavorite: movie.isFavorite,
                    rating: movie.rating,
                    synopsis: movie.synopsis,
                    tierRawValue: movie.tierRawValue,
                    createdAt: movie.createdAt,
                    updatedAt: movie.updatedAt,
                    genreIDs: movie.genres.map(\.id).sorted { $0.uuidString < $1.uuidString },
                    seasons: movie.sortedSeasons.map { season in
                        LibraryBackupArchive.SeasonRecord(
                            id: season.id,
                            number: season.number,
                            episodes: season.sortedEpisodes.map { episode in
                                LibraryBackupArchive.EpisodeRecord(
                                    id: episode.id,
                                    number: episode.number,
                                    title: episode.title,
                                    isWatched: episode.isWatched,
                                    watchedAt: episode.watchedAt
                                )
                            }
                        )
                    },
                    coverData: coverData
                )
            )
        }

        return LibraryBackupArchive(
            formatVersion: LibraryBackupArchive.currentFormatVersion,
            createdAt: .now,
            genres: genres.map {
                LibraryBackupArchive.GenreRecord(
                    id: $0.id,
                    name: $0.name,
                    catalogID: $0.catalogID,
                    createdAt: $0.createdAt
                )
            },
            movies: movieRecords
        )
    }

    private static func validate(_ archive: LibraryBackupArchive) throws {
        guard archive.formatVersion == LibraryBackupArchive.currentFormatVersion else {
            throw LibraryBackupError.unsupportedVersion
        }

        let genreIDs = archive.genres.map(\.id)
        let movieIDs = archive.movies.map(\.id)
        guard Set(genreIDs).count == genreIDs.count,
              Set(movieIDs).count == movieIDs.count
        else {
            throw LibraryBackupError.invalidValues
        }

        let normalizedGenreNames = archive.genres.map { TextNormalizer.normalize($0.name) }
        guard !normalizedGenreNames.contains(where: \.isEmpty),
              Set(normalizedGenreNames).count == normalizedGenreNames.count
        else {
            throw LibraryBackupError.invalidValues
        }

        let knownGenreIDs = Set(genreIDs)
        var seasonIDs = Set<UUID>()
        var episodeIDs = Set<UUID>()

        for movie in archive.movies {
            guard MediaKind(rawValue: movie.mediaKindRawValue) != nil,
                  ViewingStatus(rawValue: movie.statusRawValue) != nil,
                  RatingRules.validated(movie.rating) == movie.rating,
                  movie.tierRawValue.map({ MovieTier(rawValue: $0) != nil }) ?? true
            else {
                throw LibraryBackupError.invalidValues
            }

            let referencedGenreIDs = Set(movie.genreIDs)
            guard referencedGenreIDs.count == movie.genreIDs.count,
                  referencedGenreIDs.isSubset(of: knownGenreIDs)
            else {
                throw LibraryBackupError.invalidReferences
            }

            var seasonNumbers = Set<Int>()
            for season in movie.seasons {
                guard season.number > 0,
                      seasonIDs.insert(season.id).inserted,
                      seasonNumbers.insert(season.number).inserted
                else {
                    throw LibraryBackupError.invalidValues
                }

                var episodeNumbers = Set<Int>()
                for episode in season.episodes {
                    guard episode.number > 0,
                          episodeIDs.insert(episode.id).inserted,
                          episodeNumbers.insert(episode.number).inserted
                    else {
                        throw LibraryBackupError.invalidValues
                    }
                }
            }
        }
    }

    private static func deleteLibraryModels(context: ModelContext) throws {
        let movies = try context.fetch(FetchDescriptor<Movie>())
        let genres = try context.fetch(FetchDescriptor<Genre>())
        movies.forEach(context.delete)
        genres.forEach(context.delete)
    }
}
