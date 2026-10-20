import AppKit
import SwiftUI

struct EducaSidebarSurface: View {
    let reduceTransparency: Bool

    var body: some View {
        ZStack(alignment: .trailing) {
            if reduceTransparency {
                EducaColor.raised
            } else {
                NativeSidebarMaterial()
            }

            Rectangle()
                .fill(EducaColor.border)
                .frame(width: 1)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

private struct NativeSidebarMaterial: NSViewRepresentable {
    @Environment(\.colorScheme) private var colorScheme

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .sidebar
        view.blendingMode = .behindWindow
        view.state = .followsWindowActiveState
        updateAppearance(view)
        return view
    }

    func updateNSView(_ view: NSVisualEffectView, context: Context) {
        updateAppearance(view)
    }

    private func updateAppearance(_ view: NSVisualEffectView) {
        view.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
    }
}
