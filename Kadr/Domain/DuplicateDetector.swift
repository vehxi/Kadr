import Foundation

struct DuplicateCandidate: Equatable {
    let id: UUID
    let title: String
    let releaseYear: Int?
}

enum DuplicateDetector {
    static func containsDuplicate(
        title: String,
        releaseYear: Int?,
        excluding excludedID: UUID? = nil,
        in candidates: [DuplicateCandidate]
    ) -> Bool {
        let normalizedTitle = TextNormalizer.normalize(title)
        guard !normalizedTitle.isEmpty else { return false }

        return candidates.contains { candidate in
            candidate.id != excludedID
                && TextNormalizer.normalize(candidate.title) == normalizedTitle
                && candidate.releaseYear == releaseYear
        }
    }
}
