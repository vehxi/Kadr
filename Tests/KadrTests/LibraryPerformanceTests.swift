import AppKit
import Darwin
import SwiftData
import SwiftUI
import Testing
import os

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

/// Opt-in Release workload. This is an in-memory UI fixture, not the user's library.
@MainActor
struct LibraryPerformanceTests {
    @Test(.enabled(if: ProcessInfo.processInfo.environment["KADR_PERFORMANCE_COUNT"] != nil))
    func largeLibraryWorkload() async throws {
        #if !KADR_ISOLATED_TEST_HOST
        Issue.record("Build with KADR_ISOLATED_TEST_HOST to protect the real library")
        return
        #else
        let count = try #require(Int(ProcessInfo.processInfo.environment["KADR_PERFORMANCE_COUNT"] ?? ""))
        try #require([100, 1_000, 5_000].contains(count))
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-library-performance-\(UUID())")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let covers = CoverStore(directoryURL: directory.appendingPathComponent("covers"))
        defer { try? FileManager.default.removeItem(at: directory.appendingPathComponent("covers")) }
        let jpeg = try makeJPEG()
        var filenames: [String] = []
        for _ in 0..<96 { filenames.append(try await covers.write(jpeg)) }
        let container = try PersistenceController.makeContainer(inMemory: true)
        container.mainContext.autosaveEnabled = false
        for index in 0..<count {
            let movie = Movie(title: "Фильм с длинным названием № \(index)",
                mediaKind: index.isMultiple(of: 4) ? .series : .movie,
                releaseYear: 1980 + index % 46, status: index.isMultiple(of: 5) ? .watching : .watched,
                isFavorite: index.isMultiple(of: 7), rating: index.isMultiple(of: 6) ? nil : 1 + index % 5,
                coverFilename: filenames[index % filenames.count],
                tier: index.isMultiple(of: 8) ? nil : MovieTier.allCases[index % MovieTier.allCases.count],
                countryCodes: index.isMultiple(of: 9) ? [] : ["JP", index.isMultiple(of: 2) ? "US" : "GB"])
            container.mainContext.insert(movie)
        }
        try container.mainContext.save()
        let loader = CoverThumbnailLoader()
        let signposter = OSSignposter(subsystem: "app.kadr.performance", category: "library")
        let fixtureFootprint = try footprint()
        var results: [[String: Any]] = []
        for (name, filter) in [("library", LibraryFilter.all), ("map", .geography), ("tiers", .tierList)] {
            let interval = signposter.beginInterval("Screen", "\(name, privacy: .public)")
            let root = LibraryView(initialSelection: filter)
                .environment(\.locale, Locale(identifier: "ru"))
                .environment(\.colorScheme, .light)
                .environment(\.coverStore, covers)
                .environment(\.coverThumbnailLoader, loader)
                .modelContainer(container)
            let start = ContinuousClock.now
            let host = NSHostingView(rootView: root)
            let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 1080, height: 760),
                styleMask: [.titled, .closable, .resizable], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.title = "Kadr · \(count) · \(name) · isolated"
            window.contentView = host
            window.makeKeyAndOrderFront(nil)
            await Task.yield()
            host.layoutSubtreeIfNeeded()
            let initialLayout = milliseconds(start.duration(to: .now))
            try await Task.sleep(for: .milliseconds(400))
            var timings: [Double] = []
            for step in 0..<24 {
                let began = ContinuousClock.now
                if let scroll = scrollViews(in: host).filter({ ($0.documentView?.bounds.height ?? 0) > $0.contentSize.height + 10 })
                    .max(by: { $0.bounds.width < $1.bounds.width }), let document = scroll.documentView {
                    let distance = min(6_000, document.bounds.height - scroll.contentSize.height)
                    let fraction = Double(step < 12 ? step : 23 - step) / 11
                    scroll.contentView.scroll(to: CGPoint(x: 0, y: distance * fraction))
                    scroll.reflectScrolledClipView(scroll.contentView)
                }
                host.layoutSubtreeIfNeeded()
                // Includes main-run-loop scheduling delay, NOT GPU frame time/FPS.
                try await Task.sleep(for: .milliseconds(16))
                timings.append(milliseconds(began.duration(to: .now)))
            }
            let sorted = timings.sorted()
            results.append([
                "screen": name, "initial_layout_ms": initialLayout,
                "scroll_step_p95_ms": sorted[Int(Double(sorted.count - 1) * 0.95)],
                "scroll_step_max_ms": sorted.last!, "footprint_bytes": try footprint(),
                "thumbnail_cache_bytes": await loader.cachedBytes, "thumbnail_decodes": await loader.decodeCount
            ])
            if ProcessInfo.processInfo.environment["KADR_PERFORMANCE_PAUSE"] == name {
                print("PERFORMANCE PROFILE READY pid=\(ProcessInfo.processInfo.processIdentifier) screen=\(name)")
                for step in 0..<120 {
                    window.setContentSize(NSSize(width: 1080 + step % 2, height: 760))
                    try await Task.sleep(for: .milliseconds(250))
                }
            }
            window.close()
            signposter.endInterval("Screen", interval)
            try await Task.sleep(for: .milliseconds(150))
        }
        let output = ProcessInfo.processInfo.environment["KADR_PERFORMANCE_OUTPUT"]
            .map { URL(fileURLWithPath: $0) } ?? directory.appendingPathComponent("results.json")
        let data = try JSONSerialization.data(withJSONObject: [
            "count": count, "fixture_footprint_bytes": fixtureFootprint,
            "final_footprint_bytes": try footprint(), "screens": results,
            "note": "Release in-memory UI fixture; scroll steps include 16ms sleep and scheduling, not FPS. 96 synthetic covers reused."
        ], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output)
        print("Kadr library performance: \(output.path)")
        #expect(await loader.cachedBytes <= 48 * 1_024 * 1_024)
        #endif
    }

    private func scrollViews(in view: NSView) -> [NSScrollView] {
        (view as? NSScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
    }

    private func milliseconds(_ duration: Duration) -> Double {
        Double(duration.components.seconds) * 1_000 + Double(duration.components.attoseconds) / 1e15
    }

    private func footprint() throws -> UInt64 {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout.size(ofValue: info) / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        try #require(result == KERN_SUCCESS)
        return info.phys_footprint
    }

    private func makeJPEG() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 800, height: 1200, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.setFillColor(CGColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1))
        context.fill(CGRect(x: 0, y: 0, width: 800, height: 1200))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image)
            .representation(using: .jpeg, properties: [.compressionFactor: 0.85]))
    }
}
