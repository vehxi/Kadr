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
    @Test func renderRussianScreensInBothThemes() async throws {
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
            try await render(HStack(spacing: 0) {
                EducaSidebarSurface(reduceTransparency: true)
                    .overlay(alignment: .topLeading) { Text("Медиатека · Library").padding(24) }
                    .frame(width: 220)
                EducaColor.canvas
            }, name: "\(name)-opaque-sidebar-surface", size: CGSize(width: 640, height: 400), scheme: scheme, container: emptyContainer, directory: directory)
            try await render(MovieDetailView(movie: movie, onDelete: {}), name: "\(name)-detail", size: CGSize(width: 1_000, height: 600), scheme: scheme, container: container, directory: directory)
            try await render(MovieEditorView(movie: movie), name: "\(name)-editor", size: CGSize(width: 940, height: 680), scheme: scheme, container: container, directory: directory)
            try await render(TierListView(movies: [movie], openMovie: { _ in }), name: "\(name)-tiers", size: CGSize(width: 820, height: 720), scheme: scheme, container: container, directory: directory)
            try await render(MovieCardView(movie: movie, action: {}).frame(width: 240).padding(32), name: "\(name)-card", size: CGSize(width: 304, height: 500), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-narrow", size: CGSize(width: 640, height: 1100), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-wide", size: CGSize(width: 960, height: 840), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(), name: "\(name)-map-empty", size: CGSize(width: 640, height: 1100), scheme: scheme, container: emptyContainer, directory: directory)
            try await render(EducaLoadingState("Loading Map…"), name: "\(name)-loading", size: CGSize(width: 640, height: 400), scheme: scheme, container: container, directory: directory)
            try await render(GeographyView(loadGeometry: { throw CocoaError(.fileReadCorruptFile) }), name: "\(name)-error", size: CGSize(width: 640, height: 400), scheme: scheme, container: container, directory: directory)
            try await render(GenreSettingsView(), name: "\(name)-empty-genres", size: CGSize(width: 720, height: 600), scheme: scheme, container: emptyContainer, directory: directory)
        }
        print("Educa visual fixtures: \(directory.path)")
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
            .modelContainer(container)
        let host = NSHostingView(rootView: root)
        let window = NSWindow(contentRect: CGRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.appearance = NSAppearance(named: scheme == .dark ? .darkAqua : .aqua)
        window.contentView = host
        host.frame = CGRect(origin: .zero, size: size)
        defer { window.close() }
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
    }
}
