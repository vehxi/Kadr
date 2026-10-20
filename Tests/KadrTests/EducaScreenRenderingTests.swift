import AppKit
import SwiftData
import SwiftUI
import Testing

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

/// Isolated visual fixtures: never open or modify the user's on-disk library.
@MainActor
struct EducaScreenRenderingTests {
    private let coverDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent("kadr-render-covers-\(UUID())", isDirectory: true)
    private var fixtureCoverStore: CoverStore { CoverStore(directoryURL: coverDirectory) }
    private let fixtureThumbnailLoader = CoverThumbnailLoader()

    @Test func renderRussianScreensInBothThemes() async throws {
        defer { try? FileManager.default.removeItem(at: coverDirectory) }
        let container = try PersistenceController.makeContainer(inMemory: true)
        let emptyContainer = try PersistenceController.makeContainer(inMemory: true)
        let genres = [Genre(name: "Драма"), Genre(name: "Научная фантастика"), Genre(name: "Альтернативная история")]
        for genre in genres { container.mainContext.insert(genre) }
        let movie = Movie(
            title: "Невероятная история о том, как однажды закончились все фильмы",
            releaseYear: 2025, status: .watched, isFavorite: true, rating: 5,
            synopsis: "Длинное русское описание для проверки переносов. Герои путешествуют по миру и собирают истории людей, которых встречают в пути. Тихий фильм о памяти, дружбе и неожиданном возвращении домой.",
            tier: .s, genres: genres, countryCodes: ["JP", "GB", "US"]
        )
        movie.coverFilename = try await fixtureCoverStore.write(makeCoverJPEG())
        container.mainContext.insert(movie)
        container.mainContext.insert(Movie(title: "Просмотренный фильм, для которого ещё не выбраны страны производства", status: .watched))
        try container.mainContext.save()

        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("kadr-educa-screens-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        for scheme in [ColorScheme.light, .dark] {
            let name = scheme == .dark ? "dark" : "light"
            for width in [680.0, 860.0] {
                try await render(GeneralSettingsContent(
                    appearance: .constant(scheme == .dark ? "dark" : "light"),
                    appLanguage: .constant(AppLanguage.russian.rawValue)
                ) {
                    UpdateSettingsContent(displayVersion: "1.0 (100)", canCheckForUpdates: true,
                                          automaticallyChecksForUpdates: .constant(true), checkForUpdates: {})
                }, name: "\(name)-settings-\(Int(width))", size: CGSize(width: width, height: 560), scheme: scheme, container: emptyContainer, directory: directory)
            }
            try await render(GeneralSettingsContent(appearance: .constant("system"), appLanguage: .constant("system")) {
                UpdateSettingsContent(displayVersion: "1.0 (100)", canCheckForUpdates: true,
                                      automaticallyChecksForUpdates: .constant(false), checkForUpdates: {})
            }, name: "\(name)-settings-english", size: CGSize(width: 680, height: 560), scheme: scheme,
               container: emptyContainer, directory: directory, locale: Locale(identifier: "en"))
            try await render(UpdateSettingsContent(displayVersion: "1.0 (100)", canCheckForUpdates: false,
                automaticallyChecksForUpdates: .constant(false), checkForUpdates: {}).padding(24),
                name: "\(name)-settings-checking", size: CGSize(width: 680, height: 240), scheme: scheme, container: emptyContainer, directory: directory)
            try await render(GenreSettingsView(), name: "\(name)-settings-genres", size: CGSize(width: 680, height: 560), scheme: scheme, container: container, directory: directory)
            try await render(LibraryView(), name: "\(name)-library-sidebar", size: CGSize(width: 1080, height: 760), scheme: scheme, container: container, directory: directory)
            try verifyNeutralSidebar(directory.appendingPathComponent("\(name)-library-sidebar.png"))
            try await render(LibraryView(initialSelection: .tierList), name: "\(name)-tiers-sidebar", size: CGSize(width: 1080, height: 760), scheme: scheme, container: container, directory: directory)
            try verifyNeutralSidebar(directory.appendingPathComponent("\(name)-tiers-sidebar.png"))
            try await render(HStack(spacing: 0) {
                EducaSidebarSurface(reduceTransparency: true)
                    .overlay(alignment: .topLeading) { Text("Медиатека · Library").padding(24) }
                    .frame(width: 220)
                EducaColor.canvas
            }, name: "\(name)-opaque-sidebar-surface", size: CGSize(width: 640, height: 400), scheme: scheme, container: emptyContainer, directory: directory)
            try verifyNeutralSidebar(directory.appendingPathComponent("\(name)-opaque-sidebar-surface.png"), width: 640)
            try await render(MovieDetailView(movie: movie, onDelete: {}), name: "\(name)-detail", size: CGSize(width: 1_000, height: 600), scheme: scheme, container: container, directory: directory)
            try await render(MovieEditorView(movie: movie), name: "\(name)-editor", size: CGSize(width: 940, height: 680), scheme: scheme, container: container, directory: directory)
            try await render(TierListView(movies: [movie], openMovie: { _ in }), name: "\(name)-tiers", size: CGSize(width: 820, height: 720), scheme: scheme, container: container, directory: directory)
            try await render(TierListView(movies: [movie], openMovie: { _ in }), name: "\(name)-tiers-all", size: CGSize(width: 820, height: 1650), scheme: scheme, container: container, directory: directory)
            try verifyTierColors(directory.appendingPathComponent("\(name)-tiers-all.png"), scheme: scheme)
            try await render(MovieCardView(movie: movie, action: {}).frame(width: 240).padding(32), name: "\(name)-card", size: CGSize(width: 304, height: 500), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-narrow", size: CGSize(width: 640, height: 1100), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-wide", size: CGSize(width: 960, height: 840), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-empty", size: CGSize(width: 640, height: 1100), scheme: scheme, container: emptyContainer, directory: directory)
            try await render(EducaLoadingState("Loading Map…"), name: "\(name)-loading", size: CGSize(width: 640, height: 400), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(loadGeometry: { throw CocoaError(.fileReadCorruptFile) }), name: "\(name)-error", size: CGSize(width: 640, height: 400), scheme: scheme, container: container, directory: directory)
            try await render(GenreSettingsView(), name: "\(name)-empty-genres", size: CGSize(width: 720, height: 600), scheme: scheme, container: emptyContainer, directory: directory)
        }
        #expect(await fixtureThumbnailLoader.decodeCount > 0, "Visual fixtures must actually load their isolated covers")
        print("Educa visual fixtures: \(directory.path)")
    }

    /// Check the broad category area, not the thin accent stripe used by the regressed UI.
    private func verifyTierColors(_ url: URL, scheme: ColorScheme) throws {
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        let scale = CGFloat(bitmap.pixelsWide) / 820
        for tier in MovieTier.allCases {
            func matches(_ pixel: NSColor?) -> Bool {
                guard let pixel = pixel?.usingColorSpace(.sRGB) else { return false }
                let (r, g, b) = (pixel.redComponent, pixel.greenComponent, pixel.blueComponent)
                return switch tier {
                case .s: r > g + 0.3 && r > b + 0.3 && abs(g - b) < 0.2
                case .a: r > g + 0.15 && g > b + 0.2
                case .b: r > 0.7 && g > 0.7 && b < 0.4
                case .c: g > r + 0.2 && g > b + 0.15
                case .d: b > r + 0.3 && b > g + 0.15
                }
            }
            // x=48 is well inside the 88pt label and outside its centered text.
            let x = Int(48 * scale)
            let coloredRows = (0..<bitmap.pixelsHigh).filter { y in
                // Match the hue, not exact RGB: PNG/AppKit color management changes channel values.
                matches(bitmap.colorAt(x: x, y: y))
            }.count
            #expect(CGFloat(coloredRows) >= 160 * scale, "Full-height fill missing for tier \(tier.label) in \(scheme)")
            let fullHeightRows = (0..<bitmap.pixelsHigh).filter { matches(bitmap.colorAt(x: Int(80 * scale), y: $0)) }
            let top = try #require(fullHeightRows.first)
            let bottom = try #require(fullHeightRows.last)
            for y in [top + Int(4 * scale), bottom - Int(4 * scale)] {
                #expect(matches(bitmap.colorAt(x: Int(117 * scale), y: y)), "Right rank corners must be square")
                #expect(!matches(bitmap.colorAt(x: Int(35 * scale), y: y)), "Left rank corners must stay rounded")
            }
        }
    }

    private func verifyNeutralSidebar(_ url: URL, width: CGFloat = 1080) throws {
        let bitmap = try #require(NSBitmapImageRep(data: Data(contentsOf: url)))
        let scale = CGFloat(bitmap.pixelsWide) / width
        let x = Int(214 * scale)
        let reflectedRows = (0..<bitmap.pixelsHigh).filter { y in
            guard let pixel = bitmap.colorAt(x: x, y: y)?.usingColorSpace(.sRGB) else { return false }
            let tint = min(pixel.redComponent - pixel.greenComponent, pixel.redComponent - pixel.blueComponent)
            return tint > 0.008
        }.count
        #expect(reflectedRows == 0, "The sidebar must stay neutral, including on the tier list")
    }

    private func makeCoverJPEG() throws -> Data {
        let context = try #require(CGContext(data: nil, width: 800, height: 1200, bitsPerComponent: 8,
            bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        let gradient = try #require(CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [
            CGColor(red: 0.05, green: 0.25, blue: 0.5, alpha: 1),
            CGColor(red: 0.9, green: 0.55, blue: 0.3, alpha: 1)
        ] as CFArray, locations: [0, 1]))
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 800, y: 1200), options: [])
        context.setFillColor(CGColor(gray: 1, alpha: 0.85))
        context.fill(CGRect(x: 300, y: 500, width: 200, height: 200))
        let image = try #require(context.makeImage())
        return try #require(NSBitmapImageRep(cgImage: image).representation(using: .jpeg, properties: [.compressionFactor: 0.85]))
    }

    private func render<V: View>(
        _ content: V, name: String, size: CGSize, scheme: ColorScheme,
        container: ModelContainer, directory: URL, locale: Locale = Locale(identifier: "ru")
    ) async throws {
        let root = content
            .font(EducaType.body)
            .foregroundStyle(EducaColor.text)
            .tint(EducaColor.text)
            .buttonStyle(EducaButtonStyle())
            .background { EducaCanvas() }
            .environment(\.locale, locale)
            .environment(\.colorScheme, scheme)
            .environment(\.coverStore, fixtureCoverStore)
            .environment(\.coverThumbnailLoader, fixtureThumbnailLoader)
            .modelContainer(container)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        defer { window.close() }
        let preview = ProcessInfo.processInfo.environment["KADR_RENDER_PREVIEW"] == name
        if preview {
            window.styleMask = [.titled, .closable, .resizable]
            window.title = "Kadr · isolated visual fixture"
            window.makeKeyAndOrderFront(nil)
        }
        // Allow SwiftUI's layout and @Query updates to settle without presenting a window.
        await Task.yield()
        try await Task.sleep(for: .milliseconds(120))
        host.layoutSubtreeIfNeeded()
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        let png = try #require(bitmap.representation(using: .png, properties: [:]))
        #expect(bitmap.pixelsWide >= Int(size.width))
        #expect(bitmap.pixelsHigh >= Int(size.height))
        try png.write(to: directory.appendingPathComponent("\(name).png"))
        if preview {
            // Opt-in manual QA only. Regular test runs never present a window or pause here.
            try await Task.sleep(for: .seconds(60))
        }
    }
}
