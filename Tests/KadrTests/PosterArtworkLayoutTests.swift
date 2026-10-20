import AppKit
import SwiftUI
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

@MainActor
struct PosterArtworkLayoutTests {
    @Test(arguments:
        [CGSize(width: 400, height: 600), CGSize(width: 240, height: 360), CGSize(width: 96, height: 144)],
        [CGSize(width: 480, height: 600), CGSize(width: 300, height: 600), CGSize(width: 400, height: 600), CGSize(width: 800, height: 400)]
    )
    func postersFillFrameWithoutDistortion(size: CGSize, sourceSize: CGSize) throws {
        // The square must stay square; the white image must cover the entire frame.
        let image = NSImage(size: sourceSize, flipped: false) { rect in
            NSColor.white.setFill()
            rect.fill()
            NSColor.black.setFill()
            CGRect(x: rect.midX - 40, y: rect.midY - 40, width: 80, height: 80).fill()
            return true
        }
        let canvasSize = CGSize(width: size.width + 24, height: size.height + 24)
        let host = NSHostingView(rootView: FillingPosterImage(image: image)
            .frame(width: size.width, height: size.height)
            .padding(12)
            .background(Color(.sRGB, red: 1, green: 0, blue: 0, opacity: 1)))
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: canvasSize), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: canvasSize)
        defer { window.close() }
        host.layoutSubtreeIfNeeded()
        let surface = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: surface)
        let png = try #require(surface.representation(using: .png, properties: [:]))
        let bitmap = try #require(NSBitmapImageRep(data: png))
        let inset = Int(12 * CGFloat(bitmap.pixelsWide) / canvasSize.width)
        for point in [
            (inset + 2, inset + 2), (bitmap.pixelsWide - inset - 3, inset + 2),
            (inset + 2, bitmap.pixelsHigh - inset - 3),
            (bitmap.pixelsWide - inset - 3, bitmap.pixelsHigh - inset - 3)
        ] {
            let color = try #require(bitmap.colorAt(x: point.0, y: point.1)?.usingColorSpace(.sRGB))
            #expect(min(color.redComponent, color.greenComponent, color.blueComponent) > 0.9)
        }
        let outside = try #require(bitmap.colorAt(x: 2, y: bitmap.pixelsHigh / 2)?.usingColorSpace(.sRGB))
        // macOS color-matches the captured surface; test red dominance rather than exact RGB.
        #expect(outside.redComponent - max(outside.greenComponent, outside.blueComponent) > 0.4)
        let squareWidth = (0..<bitmap.pixelsWide).count {
            isBlack(bitmap.colorAt(x: $0, y: bitmap.pixelsHigh / 2))
        }
        let squareHeight = (0..<bitmap.pixelsHigh).count {
            isBlack(bitmap.colorAt(x: bitmap.pixelsWide / 2, y: $0))
        }
        #expect(squareWidth > 0 && abs(squareWidth - squareHeight) <= 2)

        if size.width == 240, sourceSize.width == 480 {
            try png.write(to: FileManager.default.temporaryDirectory.appendingPathComponent("kadr-poster-fill-check.png"))
        }
    }

    private func isBlack(_ color: NSColor?) -> Bool {
        guard let rgb = color?.usingColorSpace(.sRGB) else { return false }
        return max(rgb.redComponent, rgb.greenComponent, rgb.blueComponent) < 0.1
    }
}
