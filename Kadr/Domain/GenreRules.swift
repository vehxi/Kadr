import Foundation

enum GenreRules {
    static func isDuplicate(
        name: String,
        excluding excludedID: UUID? = nil,
        among genres: [(id: UUID, name: String)]
    ) -> Bool {
        let normalized = TextNormalizer.normalize(name)
        guard !normalized.isEmpty else { return false }

        return genres.contains {
            $0.id != excludedID && TextNormalizer.normalize($0.name) == normalized
        }
    }

    static func removing(genreID: UUID, from genreIDs: [UUID]) -> [UUID] {
        genreIDs.filter { $0 != genreID }
    }
}
