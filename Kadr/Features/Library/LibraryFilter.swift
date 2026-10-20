import SwiftUI

enum LibraryFilter: Hashable, Identifiable {
    case all
    case movies
    case series
    case favorites
    case tierList
    case geography
    case status(ViewingStatus)

    var id: String {
        switch self {
        case .all: "all"
        case .movies: "movies"
        case .series: "series"
        case .favorites: "favorites"
        case .tierList: "tier-list"
        case .geography: "geography"
        case .status(let status): status.rawValue
        }
    }

    var titleKey: LocalizedStringKey {
        switch self {
        case .all: "All Titles"
        case .movies: "Movies"
        case .series: "Series"
        case .favorites: "Favorite"
        case .tierList: "Tier List"
        case .geography: "Viewing Map"
        case .status(let status): status.titleKey
        }
    }

    var systemImage: String {
        switch self {
        case .all: "rectangle.stack"
        case .movies: "film"
        case .series: "play.rectangle.on.rectangle"
        case .favorites: "heart.fill"
        case .tierList: "square.grid.3x3.square"
        case .geography: "globe.europe.africa"
        case .status(let status): status.systemImage
        }
    }
}
