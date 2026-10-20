import Foundation
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@Suite("World map interaction")
struct WorldMapTests {
    @Test("Screen hit testing reverses zoom and pan", arguments: [CGFloat(1), 2, 5, 8])
    func reversesTransform(zoom: CGFloat) {
        let viewport = WorldMapViewport(size: CGSize(width: 700, height: 400), zoom: zoom, offset: CGSize(width: 50, height: -20))
        let location = CGPoint(x: 0.78, y: 0.32)
        let screenPoint = location.applying(viewport.transform)
        let roundTrip = viewport.mapPoint(at: screenPoint)
        #expect(abs(roundTrip.x - location.x) < 0.000001)
        #expect(abs(roundTrip.y - location.y) < 0.000001)
    }

    @Test("The overview cannot be dragged off screen")
    func clampsOverview() {
        let viewport = WorldMapViewport(size: CGSize(width: 700, height: 400))
        #expect(viewport.constrained(CGSize(width: 300, height: -300)) == .zero)
    }

    @Test("Zoomed panning is limited to the world bounds")
    func clampsZoomedPanning() {
        let viewport = WorldMapViewport(size: CGSize(width: 700, height: 400), zoom: 3)
        let offset = viewport.constrained(CGSize(width: 10_000, height: -10_000))
        #expect(offset.width == viewport.mapRect.width)
        #expect(offset.height == -viewport.mapRect.height)
    }

    @Test("Country hit testing respects polygon holes and the ocean")
    func excludesHoles() throws {
        let data = Data(#"{"countries":[{"id":"XX","name":"Example","rings":[[[0,0],[1,0],[1,1],[0,1],[0,0]],[[0.4,0.4],[0.6,0.4],[0.6,0.6],[0.4,0.6],[0.4,0.4]]]}]}"#.utf8)
        let map = try WorldMapGeometry.decode(data)
        #expect(map.country(at: CGPoint(x: 0.2, y: 0.2))?.id == "XX")
        #expect(map.country(at: CGPoint(x: 0.5, y: 0.5)) == nil)
        #expect(map.country(at: CGPoint(x: 1.5, y: 0.5)) == nil)
    }

    @Test("A corrupt geometry file throws instead of producing a partial map")
    func rejectsCorruptArchive() {
        #expect(throws: (any Error).self) {
            try WorldMapGeometry.decode(Data("not JSON".utf8))
        }
    }
}

@Suite("Viewing map statistics")
@MainActor
struct GeographyStatisticsTests {
    @Test("Unrated films count as watched without inventing a rating")
    func excludesMissingRatings() {
        let films: [Movie] = [
            Movie(title: "Первый", status: .watched, rating: 5, countryCodes: ["JP"]),
            Movie(title: "Второй", status: .watched, countryCodes: ["JP"])
        ]
        let statistics = GeographyCountryStatistics(films: films)
        #expect(statistics.count == 2)
        #expect(statistics.average == 5)
        #expect(GeographyCountryStatistics(films: []).average == nil)
    }

    @Test("No rating is visually distinct from a one-star rating")
    func distinguishesMissingData() {
        #expect(GeographyMetric.ratings.intensity(count: 1, average: nil, maximumCount: 5) == nil)
        #expect(GeographyMetric.ratings.intensity(count: 1, average: 1, maximumCount: 5) == 0)
        #expect(GeographyMetric.watches.intensity(count: 0, average: nil, maximumCount: 5) == nil)
    }

    @Test("The watch scale is monotonic and reaches full intensity")
    func watchScale() throws {
        let first = try #require(GeographyMetric.watches.intensity(count: 1, average: nil, maximumCount: 20))
        let middle = try #require(GeographyMetric.watches.intensity(count: 10, average: nil, maximumCount: 20))
        #expect(first > 0)
        #expect(first < middle)
        #expect(GeographyMetric.watches.intensity(count: 20, average: nil, maximumCount: 20) == 1)
    }

    @Test("A coproduction appears once in each participating country")
    func coproduction() {
        let film = Movie(title: "Perfect Days", status: .watched, rating: 4, countryCodes: ["JP", "DE", "JP"])
        let stats = GeographyStatistics(movies: [film])
        #expect(stats.watched.count == 1)
        #expect(stats.statistics(for: "JP").count == 1)
        #expect(stats.statistics(for: "DE").count == 1)
        #expect(stats.statistics(for: "US").count == 0)
        #expect(stats.average == 4)
    }

    @Test("Only watched records contribute; missing countries remain visible")
    func realLibraryFiltering() {
        let watched = Movie(title: "Watched", status: .watched, rating: 5, countryCodes: ["JP"])
        let missing = Movie(title: "Unknown", status: .watched)
        let series = Movie(title: "Series", mediaKind: .series, status: .watched, rating: 3, countryCodes: ["JP"])
        let excluded = [ViewingStatus.wantToWatch, .watching, .abandoned].map {
            Movie(title: $0.rawValue, status: $0, isFavorite: true, rating: 1, countryCodes: ["US"])
        }
        let stats = GeographyStatistics(movies: [watched, missing, series] + excluded)
        #expect(stats.watched.count == 3)
        #expect(stats.missingCountries.map(\.id) == [missing.id])
        #expect(stats.statistics(for: "JP").count == 2)
        #expect(stats.statistics(for: "JP").average == 4)
        #expect(stats.byCountry.count == 1)
        #expect(stats.maximumCount == 2)
    }

    @Test("Editing countries, status, ratings and deletion updates the aggregation")
    func updates() {
        let movie = Movie(title: "Film", status: .watched, rating: 5, countryCodes: ["JP"])
        movie.countryCodes = ["DE"]
        movie.rating = 2
        #expect(GeographyStatistics(movies: [movie]).statistics(for: "JP").count == 0)
        #expect(GeographyStatistics(movies: [movie]).statistics(for: "DE").average == 2)
        movie.status = .watching
        #expect(GeographyStatistics(movies: [movie]).byCountry.isEmpty)
        #expect(movie.rating == 2)
        #expect(GeographyStatistics(movies: []).maximumCount == 0)
    }

    @Test("Country identifiers normalize and localize independently of app language")
    func countries() {
        let movie = Movie(title: "Film", countryCodes: [" jp ", "DE", "jp", "invalid"])
        #expect(movie.countryCodes == ["DE", "JP"])
        #expect(ProductionCountries.name(for: "JP", locale: Locale(identifier: "ru")) == "Япония")
        #expect(ProductionCountries.name(for: "JP", locale: Locale(identifier: "en")) == "Japan")
        #expect(Movie(title: "Old").countryCodes.isEmpty)
    }
}
