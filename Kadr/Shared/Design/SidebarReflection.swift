import SwiftUI

struct SidebarReflection: Equatable, Identifiable {
    static let coordinateSpace = "library.sidebar-reflections"

    let id: String
    let color: Color
    let frame: CGRect
}

struct SidebarReflectionPreferenceKey: PreferenceKey {
    static var defaultValue: [SidebarReflection] { [] }

    static func reduce(value: inout [SidebarReflection], nextValue: () -> [SidebarReflection]) {
        value.append(contentsOf: nextValue())
    }
}

/// The actual label frames keep the reflected color aligned while the content scrolls.
struct SidebarReflectionLayer: View {
    let reflections: [SidebarReflection]
    let originY: CGFloat
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(reflections) { reflection in
                    RoundedRectangle(cornerRadius: 40, style: .continuous)
                        .fill(reflection.color.opacity(colorScheme == .dark ? 0.32 : 0.28))
                        .frame(width: 200, height: max(1, reflection.frame.height - 16))
                        .blur(radius: 40)
                        .position(x: geometry.size.width - 8, y: reflection.frame.midY - originY)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipped()
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
