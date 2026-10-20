import AppKit
import SwiftUI

/// A toolbar button is outside the split view's responder chain. Resolve its own
/// split view from an anchor inside the detail column instead of the key window.
@MainActor
final class SidebarToggleAction {
    weak var sourceView: NSView?

    @discardableResult
    func toggle() -> Bool {
        var ancestor = sourceView?.superview
        while let view = ancestor {
            if let splitView = view as? NSSplitView,
               let controller = splitView.delegate as? NSSplitViewController {
                controller.toggleSidebar(nil)
                return true
            }
            ancestor = view.superview
        }
        return false
    }
}

struct SidebarToggleAnchor: NSViewRepresentable {
    let action: SidebarToggleAction

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        action.sourceView = view
        return view
    }

    func updateNSView(_ view: NSView, context: Context) {}
}
