import Foundation

enum GeographyMetric: String, CaseIterable, Identifiable {
    case watches
    case ratings

    var id: Self { self }
    var title: String {
        switch self {
        case .watches: "Watched titles"
        case .ratings: "Average rating"
        }
    }

    func intensity(count: Int, average: Double?, maximumCount: Int) -> Double? {
        switch self {
        case .watches:
            guard count > 0, maximumCount > 0 else { return nil }
            return min(1, log1p(Double(count)) / log1p(Double(maximumCount)))
        case .ratings:
            guard let average else { return nil }
            return min(1, max(0, (average - 1) / 4))
        }
    }
}

struct GeographyCountryStatistics {
    let films: [Movie]

    var count: Int { films.count }
    var average: Double? {
        let ratings = films.compactMap { RatingRules.validated($0.rating) }
        guard !ratings.isEmpty else { return nil }
        return Double(ratings.reduce(0, +)) / Double(ratings.count)
    }
}

struct GeographyStatistics {
    let watched: [Movie]
    let missingCountries: [Movie]
    let byCountry: [String: GeographyCountryStatistics]

    init(movies: [Movie]) {
        watched = movies.filter { $0.status == .watched }
        missingCountries = watched.filter { $0.countryCodes.isEmpty }
        var grouped: [String: [Movie]] = [:]
        for movie in watched {
            for code in movie.countryCodes {
                grouped[code, default: []].append(movie)
            }
        }
        byCountry = grouped.mapValues { GeographyCountryStatistics(films: $0) }
    }

    var maximumCount: Int { byCountry.values.map(\.count).max() ?? 0 }
    var average: Double? { GeographyCountryStatistics(films: watched).average }

    func statistics(for code: String) -> GeographyCountryStatistics {
        byCountry[code] ?? GeographyCountryStatistics(films: [])
    }
}
