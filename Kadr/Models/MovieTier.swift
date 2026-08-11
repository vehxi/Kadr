import SwiftUI

enum MovieTier: String, CaseIterable, Identifiable {
    case s
    case a
    case b
    case c
    case d

    var id: String { rawValue }

    var label: String {
        rawValue.uppercased()
    }

    var color: Color {
        switch self {
        case .s: .red
        case .a: .orange
        case .b: .yellow
        case .c: .green
        case .d: .blue
        }
    }
}
