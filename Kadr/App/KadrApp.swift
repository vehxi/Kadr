import SwiftData
import SwiftUI

@main
struct KadrApp: App {
    private let modelContainer: ModelContainer
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue

    init() {
        do {
            modelContainer = try PersistenceController.makeContainer()
        } catch {
            fatalError("Unable to create the local database: \(error.localizedDescription)")
        }
    }

    private var appLanguage: AppLanguage {
        AppLanguage(rawValue: appLanguageRawValue) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            LibraryView()
                .environment(\.locale, appLanguage.locale)
                .task {
                    try? await cleanupOrphanedCovers()
                }
        }
        .modelContainer(modelContainer)
        .commands {
            AppCommands()
        }
        .defaultSize(width: 1_080, height: 720)

        Settings {
            SettingsView()
                .environment(\.locale, appLanguage.locale)
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func cleanupOrphanedCovers() async throws {
        let context = modelContainer.mainContext
        let movies = try context.fetch(FetchDescriptor<Movie>())
        let filenames = Set(movies.compactMap(\.coverFilename))
        try await CoverStore.shared.removeOrphans(referencedFilenames: filenames)
    }
}
