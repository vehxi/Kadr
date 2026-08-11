import SwiftUI

enum MediaKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case movie
    case series

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .movie: "Movie"
        case .series: "Series"
        }
    }

    var systemImage: String {
        switch self {
        case .movie: "film"
        case .series: "play.rectangle.on.rectangle"
        }
    }
}
