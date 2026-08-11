import Foundation
import SwiftUI

enum AppLanguage: String, CaseIterable, Identifiable {
    case system
    case russian
    case english

    var id: String { rawValue }

    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "System Language"
        case .russian: "Russian"
        case .english: "English"
        }
    }

    var locale: Locale {
        switch self {
        case .system: .autoupdatingCurrent
        case .russian: Locale(identifier: "ru")
        case .english: Locale(identifier: "en")
        }
    }
}
