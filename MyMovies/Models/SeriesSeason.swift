import Foundation
import SwiftData

@Model
final class SeriesSeason {
    @Attribute(.unique) var id: UUID
    var number: Int
    var movie: Movie?

    @Relationship(deleteRule: .cascade, inverse: \SeriesEpisode.season)
    var episodes: [SeriesEpisode]

    init(
        id: UUID = UUID(),
        number: Int,
        movie: Movie? = nil,
        episodes: [SeriesEpisode] = []
    ) {
        self.id = id
        self.number = number
        self.movie = movie
        self.episodes = episodes
    }

    var sortedEpisodes: [SeriesEpisode] {
        episodes.sorted { $0.number < $1.number }
    }

    var watchedEpisodeCount: Int {
        episodes.lazy.filter(\.isWatched).count
    }
}

@Model
final class SeriesEpisode {
    @Attribute(.unique) var id: UUID
    var number: Int
    var title: String
    var isWatched: Bool
    var watchedAt: Date?
    var season: SeriesSeason?

    init(
        id: UUID = UUID(),
        number: Int,
        title: String = "",
        isWatched: Bool = false,
        watchedAt: Date? = nil,
        season: SeriesSeason? = nil
    ) {
        self.id = id
        self.number = number
        self.title = title
        self.isWatched = isWatched
        self.watchedAt = watchedAt
        self.season = season
    }
}
