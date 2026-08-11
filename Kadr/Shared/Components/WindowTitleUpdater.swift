import AppKit
import SwiftUI

struct WindowTitleUpdater: NSViewRepresentable {
    let title: String

    func makeNSView(context: Context) -> NSView {
        TitleTrackingView(title: title)
    }

    func updateNSView(_ view: NSView, context: Context) {
        guard let view = view as? TitleTrackingView else { return }
        view.title = title
        view.applyTitle()
    }
}

private final class TitleTrackingView: NSView {
    var title: String

    init(title: String) {
        self.title = title
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        applyTitle()
    }

    func applyTitle() {
        let nextTitle = title
        Task { @MainActor [weak self] in
            await Task.yield()
            self?.window?.title = nextTitle
        }
    }
}
