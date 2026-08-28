import SwiftUI

struct AppCommands: Commands {
    @ObservedObject var updateController: UpdateController

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button("Check for Updates…") {
                updateController.checkForUpdates()
            }
            .disabled(!updateController.canCheckForUpdates)
        }

        CommandGroup(replacing: .newItem) {
            Button("Add Title") {
                NotificationCenter.default.post(name: .newMovieRequested, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
        }
    }
}
