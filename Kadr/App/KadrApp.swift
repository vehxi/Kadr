import SwiftData
import SwiftUI

@main
struct KadrApp: App {
    private let modelContainer: ModelContainer
    @StateObject private var updateController: UpdateController
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue

    init() {
        _updateController = StateObject(wrappedValue: UpdateController())

        do {
            #if KADR_ISOLATED_TEST_HOST
            // Explicit benchmark/test build only: never open the user's database.
            modelContainer = try PersistenceController.makeContainer(inMemory: true)
            #else
            modelContainer = try PersistenceController.makeContainer()
            #endif
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
                .educaRoot()
                .task {
                    try? await cleanupOrphanedCovers()
                }
        }
        .modelContainer(modelContainer)
        .commands {
            AppCommands(updateController: updateController)
        }
        .defaultSize(width: 1_080, height: 720)

        Settings {
            SettingsView(updateController: updateController)
                .environment(\.locale, appLanguage.locale)
                .educaRoot()
        }
        .modelContainer(modelContainer)
    }

    @MainActor
    private func cleanupOrphanedCovers() async throws {
        #if !KADR_ISOLATED_TEST_HOST
        let context = modelContainer.mainContext
        let movies = try context.fetch(FetchDescriptor<Movie>())
        let filenames = Set(movies.compactMap(\.coverFilename))
        try await CoverStore.shared.removeOrphans(referencedFilenames: filenames)
        #endif
    }
}
