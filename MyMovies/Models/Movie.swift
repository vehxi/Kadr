import Foundation
import SwiftData

@Model
final class Movie {
    private static let legacyFavoriteStatus = "favorite"

    @Attribute(.unique) var id: UUID
    var title: String
    var normalizedTitle: String
    var mediaKindRawValue: String = MediaKind.movie.rawValue
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

    @Relationship(deleteRule: .nullify, inverse: \Genre.movies)
    var genres: [Genre]

    @Relationship(deleteRule: .cascade, inverse: \SeriesSeason.movie)
    var seasons: [SeriesSeason]

    init(
        id: UUID = UUID(),
        title: String,
        mediaKind: MediaKind = .movie,
        releaseYear: Int? = nil,
        releaseEndYear: Int? = nil,
        status: ViewingStatus = .wantToWatch,
        isFavorite: Bool = false,
        rating: Int? = nil,
        synopsis: String = "",
        coverFilename: String? = nil,
        tier: MovieTier? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now,
        genres: [Genre] = [],
        seasons: [SeriesSeason] = []
    ) {
        self.id = id
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.normalizedTitle = TextNormalizer.normalize(title)
        self.mediaKindRawValue = mediaKind.rawValue
        self.releaseYear = releaseYear
        self.releaseEndYear = Self.normalizedEndYear(
            releaseEndYear,
            startingAt: releaseYear,
            mediaKind: mediaKind
        )
        self.statusRawValue = status.rawValue
        self.favoriteFlag = isFavorite
        self.rating = RatingRules.validated(rating, for: status)
        self.synopsis = synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coverFilename = coverFilename
        self.tierRawValue = tier?.rawValue
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.genres = genres
        self.seasons = seasons
    }

    var mediaKind: MediaKind {
        get { MediaKind(rawValue: mediaKindRawValue) ?? .movie }
        set {
            mediaKindRawValue = newValue.rawValue
            if newValue == .series {
                tier = nil
            } else {
                releaseEndYear = nil
            }
        }
    }

    var releasePeriodText: String? {
        guard let releaseYear else { return nil }
        guard mediaKind == .series,
              let releaseEndYear,
              releaseEndYear != releaseYear
        else {
            return String(releaseYear)
        }
        return "\(releaseYear)–\(releaseEndYear)"
    }

    var sortedSeasons: [SeriesSeason] {
        seasons.sorted { $0.number < $1.number }
    }

    var episodeCount: Int {
        seasons.reduce(0) { $0 + $1.episodes.count }
    }

    var watchedEpisodeCount: Int {
        seasons.reduce(0) { $0 + $1.watchedEpisodeCount }
    }

    var status: ViewingStatus {
        get {
            if statusRawValue == Self.legacyFavoriteStatus {
                return .watched
            }
            return ViewingStatus(rawValue: statusRawValue) ?? .wantToWatch
        }
        set {
            if statusRawValue == Self.legacyFavoriteStatus {
                favoriteFlag = true
            }
            statusRawValue = newValue.rawValue
            rating = RatingRules.validated(rating, for: newValue)
        }
    }

    var isFavorite: Bool {
        get { favoriteFlag || statusRawValue == Self.legacyFavoriteStatus }
        set {
            favoriteFlag = newValue
            if statusRawValue == Self.legacyFavoriteStatus {
                statusRawValue = ViewingStatus.watched.rawValue
            }
        }
    }

    @discardableResult
    func migrateLegacyFavoriteIfNeeded() -> Bool {
        guard statusRawValue == Self.legacyFavoriteStatus else { return false }
        favoriteFlag = true
        statusRawValue = ViewingStatus.watched.rawValue
        return true
    }

    var tier: MovieTier? {
        get { tierRawValue.flatMap(MovieTier.init(rawValue:)) }
        set { tierRawValue = newValue?.rawValue }
    }

    func update(
        title: String,
        mediaKind: MediaKind,
        releaseYear: Int?,
        releaseEndYear: Int?,
        status: ViewingStatus,
        isFavorite: Bool,
        rating: Int?,
        synopsis: String,
        coverFilename: String?,
        genres: [Genre],
        now: Date = .now
    ) {
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        normalizedTitle = TextNormalizer.normalize(title)
        self.mediaKind = mediaKind
        self.releaseYear = releaseYear
        self.releaseEndYear = Self.normalizedEndYear(
            releaseEndYear,
            startingAt: releaseYear,
            mediaKind: mediaKind
        )
        statusRawValue = status.rawValue
        favoriteFlag = isFavorite
        self.rating = RatingRules.validated(rating, for: status)
        self.synopsis = synopsis.trimmingCharacters(in: .whitespacesAndNewlines)
        self.coverFilename = coverFilename
        self.genres = genres
        updatedAt = now
    }

    private static func normalizedEndYear(
        _ endYear: Int?,
        startingAt startYear: Int?,
        mediaKind: MediaKind
    ) -> Int? {
        guard mediaKind == .series, let startYear else { return nil }
        return max(endYear ?? startYear, startYear)
    }
}
