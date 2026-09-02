import Foundation
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@Suite("Rating rules")
struct RatingRulesTests {
    @Test("Accepts ratings from one through five", arguments: 1...5)
    func acceptsValidRatings(rating: Int) {
        #expect(RatingRules.validated(rating) == rating)
    }

    @Test("Rejects ratings outside the supported range", arguments: [-1, 0, 6])
    func rejectsInvalidRatings(rating: Int) {
        #expect(RatingRules.validated(rating) == nil)
    }

    @Test("Preserves an absent rating")
    func preservesNil() {
        #expect(RatingRules.validated(nil) == nil)
    }
}

@Suite("Text normalization")
struct TextNormalizerTests {
    @Test("Collapses surrounding and repeated whitespace")
    func formatsDisplayName() {
        #expect(TextNormalizer.displayName("  The\n  Matrix\t") == "The Matrix")
    }

    @Test("Normalizes case and whitespace deterministically")
    func normalizesForComparison() {
        #expect(TextNormalizer.normalize("  THE   Matrix ") == "the matrix")
    }
}

@Suite("Duplicate detection")
struct DuplicateDetectorTests {
    @Test("Matches normalized title and release year")
    func detectsDuplicate() {
        let candidates = [
            DuplicateCandidate(id: UUID(), title: "The Matrix", releaseYear: 1999)
        ]

        #expect(
            DuplicateDetector.containsDuplicate(
                title: "  THE   matrix ",
                releaseYear: 1999,
                in: candidates
            )
        )
    }

    @Test("Requires the release year to match")
    func distinguishesReleaseYears() {
        let candidates = [
            DuplicateCandidate(id: UUID(), title: "Dune", releaseYear: 1984)
        ]

        #expect(
            !DuplicateDetector.containsDuplicate(
                title: "Dune",
                releaseYear: 2021,
                in: candidates
            )
        )
    }

    @Test("Excludes the record being edited")
    func excludesCurrentRecord() {
        let id = UUID()
        let candidates = [DuplicateCandidate(id: id, title: "Arrival", releaseYear: 2016)]

        #expect(
            !DuplicateDetector.containsDuplicate(
                title: "Arrival",
                releaseYear: 2016,
                excluding: id,
                in: candidates
            )
        )
    }

    @Test("Does not treat an empty normalized title as a duplicate")
    func ignoresEmptyTitle() {
        let candidates = [DuplicateCandidate(id: UUID(), title: "", releaseYear: nil)]

        #expect(
            !DuplicateDetector.containsDuplicate(
                title: "  \n ",
                releaseYear: nil,
                in: candidates
            )
        )
    }
}

@Suite("Genre rules")
struct GenreRulesTests {
    @Test("Detects a duplicate genre after normalization")
    func detectsDuplicate() {
        let genres = [(id: UUID(), name: "Science Fiction")]

        #expect(GenreRules.isDuplicate(name: " science   FICTION ", among: genres))
    }

    @Test("Excludes the genre being edited")
    func excludesCurrentGenre() {
        let id = UUID()
        let genres = [(id: id, name: "Drama")]

        #expect(!GenreRules.isDuplicate(name: "Drama", excluding: id, among: genres))
    }

    @Test("Removes every occurrence of a genre identifier")
    func removesGenreID() {
        let removedID = UUID()
        let retainedID = UUID()

        #expect(
            GenreRules.removing(
                genreID: removedID,
                from: [removedID, retainedID, removedID]
            ) == [retainedID]
        )
    }
}

@Suite("Status counters")
struct StatusCounterTests {
    @Test("Counts each viewing status independently")
    func countsStatuses() {
        let snapshots = [
            StatusSnapshot(status: .wantToWatch),
            StatusSnapshot(status: .watching),
            StatusSnapshot(status: .watching),
            StatusSnapshot(status: .watched, isFavorite: true)
        ]
        let counts = StatusCounter.counts(snapshots)

        #expect(counts[.wantToWatch] == 1)
        #expect(counts[.watching] == 2)
        #expect(counts[.watched] == 1)
        #expect(counts[.abandoned] == nil)
    }

    @Test("Counts favorites independently of viewing status")
    func countsFavorites() {
        let snapshots = [
            StatusSnapshot(status: .wantToWatch, isFavorite: true),
            StatusSnapshot(status: .watching),
            StatusSnapshot(status: .abandoned, isFavorite: true)
        ]

        #expect(StatusCounter.favoriteCount(snapshots) == 2)
    }
}

@Suite("Genre catalog")
struct GenreCatalogTests {
    @Test("Catalog identifiers are unique")
    func hasUniqueIDs() {
        let ids = GenreCatalog.definitions.map(\.id)
        #expect(Set(ids).count == ids.count)
    }

    @Test("Finds definitions by identifier and localized name")
    func findsDefinitions() throws {
        let drama = try #require(GenreCatalog.definition(id: "drama"))

        #expect(GenreCatalog.definition(matching: " drama ")?.id == drama.id)
        #expect(GenreCatalog.definition(matching: " ДРАМА ")?.id == drama.id)
        #expect(drama.name(for: Locale(identifier: "en")) == "Drama")
        #expect(drama.name(for: Locale(identifier: "ru")) == "Драма")
    }
}
