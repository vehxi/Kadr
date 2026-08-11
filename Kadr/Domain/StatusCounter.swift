struct StatusSnapshot: Equatable {
    let status: ViewingStatus
    let isFavorite: Bool

    init(status: ViewingStatus, isFavorite: Bool = false) {
        self.status = status
        self.isFavorite = isFavorite
    }
}

enum StatusCounter {
    static func counts(_ movies: [StatusSnapshot]) -> [ViewingStatus: Int] {
        Dictionary(grouping: movies, by: \.status).mapValues(\.count)
    }

    static func favoriteCount(_ movies: [StatusSnapshot]) -> Int {
        movies.lazy.filter(\.isFavorite).count
    }
}
