import AppKit
import SwiftData
import SwiftUI
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@MainActor
struct GeographyListLoadingTests {
    @Test func countryPanelDoesNotLoadEveryOffscreenCover() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-country-list-test-\(UUID())")
        defer { try? FileManager.default.removeItem(at: directory) }
        let covers = CoverStore(directoryURL: directory)
        let loader = CoverThumbnailLoader()
        let context = try #require(CGContext(data: nil, width: 40, height: 60, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(gray: 0.5, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 40, height: 60))
        let image = try #require(context.makeImage())
        let jpeg = try #require(NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [:]))
        let container = try PersistenceController.makeContainer(inMemory: true)
        for index in 0..<100 {
            let filename = try await covers.write(jpeg)
            container.mainContext.insert(Movie(title: "Film \(index)", status: .watched,
                coverFilename: filename, countryCodes: ["JP"]))
        }
        try container.mainContext.save()
        let root = GeographyView()
            .environment(\.coverStore, covers)
            .environment(\.coverThumbnailLoader, loader)
            .modelContainer(container)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 960, height: 760),
            styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        defer { window.close() }
        await Task.yield()
        try await Task.sleep(for: .milliseconds(300))
        host.layoutSubtreeIfNeeded()
        try await Task.sleep(for: .milliseconds(100))
        let decoded = await loader.decodeCount
        #expect(decoded > 0, "The country panel must display actual covers")
        #expect(decoded < 50, "A small viewport must not decode 100 offscreen covers")
    }
}
