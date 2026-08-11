import Foundation
import SwiftData

@Model
final class Genre {
    @Attribute(.unique) var id: UUID
    var name: String
    @Attribute(.unique) var normalizedName: String
    var createdAt: Date

    var movies: [Movie]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        movies: [Movie] = []
    ) {
        self.id = id
        self.name = TextNormalizer.displayName(name)
        self.normalizedName = TextNormalizer.normalize(name)
        self.createdAt = createdAt
        self.movies = movies
    }

    func rename(to newName: String) {
        name = TextNormalizer.displayName(newName)
        normalizedName = TextNormalizer.normalize(newName)
    }
}
