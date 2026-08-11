import Foundation

struct MovieSheet: Identifiable {
    enum Content {
        case add
        case detail(Movie)
    }

    let id = UUID()
    let content: Content
}
