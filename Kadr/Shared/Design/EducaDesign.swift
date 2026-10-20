import AppKit
import SwiftUI

// Educa's native macOS vocabulary. Dynamic sRGB colors also work in sheets and popovers.
enum EducaColor {
    static let canvas = adaptive(light: 0xEDEFF1, dark: 0x0C0D0F)
    static let panel = adaptive(light: 0xFBFCFD, dark: 0x161719)
    static let raised = adaptive(light: 0xDFE1E5, dark: 0x202224)
    static let text = adaptive(light: 0x1D1F23, dark: 0xEAEBED)
    static let secondaryText = adaptive(light: 0x505357, dark: 0x96989B)
    static let mutedText = adaptive(light: 0x5D6165, dark: 0x5E6164)
    static let border = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.10, darkAlpha: 0.08)
    static let secondaryButton = adaptive(light: 0x000000, dark: 0xFFFFFF, lightAlpha: 0.05, darkAlpha: 0.06)
    static let primaryButton = text
    static let primaryButtonText = adaptive(light: 0xFBFCFD, dark: 0x0C0D0F)

    private static func adaptive(
        light: UInt32, dark: UInt32, lightAlpha: CGFloat = 1, darkAlpha: CGFloat = 1
    ) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            let hex = isDark ? dark : light
            return NSColor(
                srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
                green: CGFloat((hex >> 8) & 0xFF) / 255,
                blue: CGFloat(hex & 0xFF) / 255,
                alpha: isDark ? darkAlpha : lightAlpha
            )
        })
    }
}

enum EducaType {
    // Educa only provides web WOFF2 fonts; use SF's complete native Cyrillic coverage.
    static let screen = Font.system(size: 30, weight: .semibold)
    static let title = Font.system(size: 22, weight: .semibold)
    static let heading = Font.system(size: 15, weight: .semibold)
    static let body = Font.system(size: 14)
    static let control = Font.system(size: 13, weight: .medium)
    static let caption = Font.system(size: 12)
    static let label = Font.system(size: 11, weight: .semibold)
}

enum EducaSpace {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 12
    static let lg: CGFloat = 16
    static let panel: CGFloat = 24
    static let page: CGFloat = 32
}

enum EducaRadius {
    static let field: CGFloat = 10
    static let button: CGFloat = 14
    static let panel: CGFloat = 24
}

enum EducaMotion {
    static let feedback = Animation.timingCurve(0.23, 1, 0.32, 1, duration: 0.16)
}

enum AppAppearance: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "System Theme"
        case .light: "Light Theme"
        case .dark: "Dark Theme"
        }
    }

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }

    init(storedValue: String) {
        self = Self(rawValue: storedValue) ?? .system
    }
}

struct EducaCanvas: View {
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        EducaColor.canvas
            .overlay {
                if colorScheme == .dark {
                    RadialGradient(
                        colors: [.white.opacity(0.025), .clear],
                        center: .bottom, startRadius: 0, endRadius: 600
                    )
                }
            }
            .ignoresSafeArea()
            .allowsHitTesting(false)
    }
}

private struct EducaRootStyle: ViewModifier {
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue

    func body(content: Content) -> some View {
        content
            .font(EducaType.body)
            .foregroundStyle(EducaColor.text)
            .tint(EducaColor.text)
            .buttonStyle(EducaButtonStyle())
            .background { EducaCanvas() }
            .preferredColorScheme(AppAppearance(storedValue: appearance).colorScheme)
    }
}

struct EducaButtonStyle: ButtonStyle {
    enum Kind { case primary, secondary, icon }
    var kind: Kind = .secondary

    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.isFocused) private var isFocused
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(EducaType.control)
            .foregroundStyle(kind == .primary ? EducaColor.primaryButtonText : EducaColor.text)
            .padding(.horizontal, kind == .icon ? 0 : EducaSpace.lg)
            .frame(minWidth: 40, minHeight: 40)
            .background {
                RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous)
                    .fill(kind == .primary ? EducaColor.primaryButton : EducaColor.secondaryButton)
                    .overlay {
                        RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous)
                            .fill((kind == .primary ? EducaColor.primaryButtonText : EducaColor.text)
                                .opacity(isHovering && isEnabled ? 0.08 : 0))
                    }
            }
            .overlay {
                RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous)
                    .strokeBorder(isFocused ? EducaColor.text : EducaColor.border, lineWidth: isFocused ? 2 : 1)
            }
            .contentShape(RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous))
            .opacity(isEnabled ? 1 : 0.4)
            .scaleEffect(configuration.isPressed && isEnabled && !reduceMotion ? 0.98 : 1)
            .animation(reduceMotion ? nil : EducaMotion.feedback, value: configuration.isPressed)
            .animation(reduceMotion ? nil : EducaMotion.feedback, value: isHovering)
            .onHover { isHovering = $0 }
    }
}

// Poster controls need press feedback without button chrome or changing their layout.
struct EducaPosterButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.985 : 1)
            .animation(reduceMotion ? nil : EducaMotion.feedback, value: configuration.isPressed)
    }
}

@MainActor
struct EducaTextFieldStyle: @MainActor TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .textFieldStyle(.plain)
            .font(EducaType.body)
            .modifier(EducaInputChrome())
    }
}

private struct EducaInputChrome: ViewModifier {
    @FocusState private var isFocused: Bool

    func body(content: Content) -> some View {
        content
            .focused($isFocused)
            .padding(.horizontal, EducaSpace.md)
            .frame(minHeight: 40)
            .background { EducaFieldSurface(isFocused: isFocused) }
    }
}

struct EducaFieldSurface: View {
    var isFocused = false

    var body: some View {
        RoundedRectangle(cornerRadius: EducaRadius.field, style: .continuous)
            .fill(EducaColor.secondaryButton)
            .overlay {
                RoundedRectangle(cornerRadius: EducaRadius.field, style: .continuous)
                    .strokeBorder(isFocused ? EducaColor.text.opacity(0.65) : EducaColor.border, lineWidth: isFocused ? 2 : 1)
            }
    }
}

private struct EducaPanelStyle: ViewModifier {
    var padding: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(EducaColor.panel, in: RoundedRectangle(cornerRadius: EducaRadius.panel, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: EducaRadius.panel, style: .continuous)
                    .strokeBorder(EducaColor.border)
            }
            .overlay {
                if colorScheme == .dark {
                    RoundedRectangle(cornerRadius: EducaRadius.panel, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.035), .clear], startPoint: .top, endPoint: .center))
                }
            }
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.12 : 0.035), radius: 2, y: 1)
            .shadow(color: .black.opacity(colorScheme == .dark ? 0.16 : 0.045), radius: 16, y: 8)
    }
}

struct EducaDivider: View {
    var body: some View {
        Rectangle().fill(EducaColor.border).frame(height: 1).accessibilityHidden(true)
    }
}

struct EducaLoadingState: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) { self.title = title }

    var body: some View {
        ProgressView(title)
            .tint(EducaColor.text)
            .font(EducaType.body)
            .foregroundStyle(EducaColor.secondaryText)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

extension View {
    func educaRoot() -> some View { modifier(EducaRootStyle()) }
    func educaPanel(padding: CGFloat = EducaSpace.panel) -> some View {
        modifier(EducaPanelStyle(padding: padding))
    }
    func educaScreenTitle() -> some View {
        font(EducaType.screen).tracking(-0.6).foregroundStyle(EducaColor.text)
    }
}
