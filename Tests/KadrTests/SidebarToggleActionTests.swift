import AppKit
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@MainActor
struct SidebarToggleActionTests {
    @Test("A custom toolbar action reaches its own native split controller without a responder chain")
    func targetsOwningSplitView() {
        let first = SidebarControllerSpy()
        let second = SidebarControllerSpy()
        let firstAnchor = NSView()
        let secondAnchor = NSView()
        first.splitView.addSubview(firstAnchor)
        second.splitView.addSubview(secondAnchor)
        let firstAction = SidebarToggleAction()
        let secondAction = SidebarToggleAction()
        firstAction.sourceView = firstAnchor
        secondAction.sourceView = secondAnchor

        #expect(firstAction.toggle())
        #expect(first.toggleCount == 1)
        #expect(second.toggleCount == 0)
        #expect(secondAction.toggle())
        #expect(second.toggleCount == 1)
    }

    @Test("A detached anchor safely falls back to SwiftUI visibility")
    func detachedAnchor() {
        let action = SidebarToggleAction()
        #expect(!action.toggle())
        let anchor = NSView()
        action.sourceView = anchor
        #expect(!action.toggle())
    }
}

@MainActor
private final class SidebarControllerSpy: NSSplitViewController {
    var toggleCount = 0

    override func toggleSidebar(_ sender: Any?) {
        toggleCount += 1
    }
}
