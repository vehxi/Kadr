import AppKit
import Darwin
import ImageIO
import UniformTypeIdentifiers
import os

/// Headless workload, not an alternative way to launch Kadr.app.
/// Uses only explicitly supplied synthetic fixtures; never opens Application Support.
@main
struct CoverLoadingBenchmark {
    @MainActor
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count >= 3 else {
            print("Usage: cover-benchmark prepare|legacy|optimized FIXTURE_DIRECTORY [repetitions]")
            return
        }
        let mode = arguments[1]
        guard ["prepare", "legacy", "optimized"].contains(mode) else { throw CocoaError(.coderInvalidValue) }
        let directory = URL(fileURLWithPath: arguments[2], isDirectory: true)
        if mode == "prepare" {
            try prepare(directory)
            return
        }
        let repetitions = arguments.count > 3 ? Int(arguments[3]) ?? 3 : 3
        guard (1...100).contains(repetitions) else { throw CocoaError(.coderInvalidValue) }
        let posterSize = CGSize(width: 480, height: 720) // 240×360pt at 2×.
        let signposter = OSSignposter(subsystem: "app.kadr.performance", category: "covers")
        #if COVER_THUMBNAILS_AVAILABLE
        let loader = CoverThumbnailLoader()
        #endif
        var durations: [Double] = []
        var retained: [NSImage] = []
        var sourceBytes = 0
        var maximumSourceBytes = 0
        let clock = ContinuousClock()
        let started = clock.now
        for _ in 0..<repetitions {
            for page in 0..<4 {
                // Revisit each page once: the second visit tests reuse, not OS cold disk I/O.
                for _ in 0..<2 {
                    retained.removeAll()
                    sourceBytes = 0
                    for index in (page * 24)..<(page * 24 + 24) {
                        let url = directory.appendingPathComponent("cover-\(index).jpg")
                        let interval = signposter.beginInterval("LoadAndDraw")
                        let start = clock.now
                        let image: NSImage
                        if mode == "legacy" {
                            image = try autoreleasepool {
                                guard let image = NSImage(contentsOf: url) else { throw CocoaError(.fileReadCorruptFile) }
                                return image
                            }
                        } else {
                            #if COVER_THUMBNAILS_AVAILABLE
                            guard let cgImage = await loader.image(at: url, size: CoverThumbnailSize(width: 480, height: 720)) else {
                                throw CocoaError(.fileReadCorruptFile)
                            }
                            image = NSImage(cgImage: cgImage, size: posterSize)
                            #else
                            throw CocoaError(.featureUnsupported)
                            #endif
                        }
                        try autoreleasepool { try draw(image, size: posterSize) }
                        durations.append(milliseconds(start.duration(to: clock.now)))
                        signposter.endInterval("LoadAndDraw", interval)
                        sourceBytes += autoreleasepool {
                            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return 0 }
                            return cgImage.bytesPerRow * cgImage.height
                        }
                        retained.append(image)
                    }
                    maximumSourceBytes = max(maximumSourceBytes, sourceBytes)
                }
            }
        }
        let elapsed = milliseconds(started.duration(to: clock.now))
        var usage = rusage()
        getrusage(RUSAGE_SELF, &usage)
        let sorted = durations.sorted()
        let report: [String: Any] = [
            "mode": mode, "loads": durations.count,
            "elapsed_ms": elapsed,
            "load_draw_median_ms": sorted[sorted.count / 2],
            "load_draw_p95_ms": sorted[Int(Double(sorted.count - 1) * 0.95)],
            "peak_rss_bytes": usage.ru_maxrss,
            "visible_source_pixel_bytes": maximumSourceBytes,
            "note": "Synthetic 96-cover workload, 24 visible covers, 480x720 pixels; not whole-app RAM/FPS."
        ]
        let data = try JSONSerialization.data(withJSONObject: report, options: [.prettyPrinted, .sortedKeys])
        print(String(decoding: data, as: UTF8.self))
        withExtendedLifetime(retained) {}
    }

    private static func milliseconds(_ duration: Duration) -> Double {
        let components = duration.components
        return Double(components.seconds) * 1_000 + Double(components.attoseconds) / 1e15
    }

    @MainActor
    private static func draw(_ image: NSImage, size: CGSize) throws {
        guard let context = CGContext(data: nil, width: Int(size.width), height: Int(size.height),
                                      bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.coderInvalidValue)
        }
        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = NSGraphicsContext(cgContext: context, flipped: false)
        image.draw(in: CGRect(origin: .zero, size: size))
        context.flush()
    }

    private static func prepare(_ directory: URL) throws {
        if FileManager.default.fileExists(atPath: directory.path),
           !(try FileManager.default.contentsOfDirectory(atPath: directory.path)).isEmpty {
            throw CocoaError(.fileWriteFileExists)
        }
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        guard let context = CGContext(data: nil, width: 1067, height: 1600, bitsPerComponent: 8,
                                      bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(),
                                      bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
            throw CocoaError(.coderInvalidValue)
        }
        for index in 0..<800 {
            context.setFillColor(CGColor(red: CGFloat((index * 73) % 255) / 255,
                                         green: CGFloat((index * 37) % 255) / 255,
                                         blue: CGFloat((index * 19) % 255) / 255, alpha: 1))
            context.fill(CGRect(x: 0, y: index * 2, width: 1067, height: 2))
        }
        guard let image = context.makeImage() else { throw CocoaError(.coderInvalidValue) }
        for index in 0..<96 {
            let url = directory.appendingPathComponent("cover-\(index).jpg")
            guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil) else {
                throw CocoaError(.fileWriteUnknown)
            }
            CGImageDestinationAddImage(destination, image, [kCGImageDestinationLossyCompressionQuality: 0.85] as CFDictionary)
            guard CGImageDestinationFinalize(destination) else { throw CocoaError(.fileWriteUnknown) }
        }
        print("Prepared 96 synthetic JPEG covers (1067x1600) in \(directory.path)")
    }
}
