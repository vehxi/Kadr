import SwiftUI

struct UpdateSettingsSection: View {
    @ObservedObject var updateController: UpdateController

    var body: some View {
        UpdateSettingsContent(
            displayVersion: updateController.displayVersion,
            canCheckForUpdates: updateController.canCheckForUpdates,
            automaticallyChecksForUpdates: $updateController.automaticallyChecksForUpdates,
            checkForUpdates: updateController.checkForUpdates
        )
    }
}

struct UpdateSettingsContent: View {
    let displayVersion: String
    let canCheckForUpdates: Bool
    @Binding var automaticallyChecksForUpdates: Bool
    let checkForUpdates: () -> Void

    var body: some View {
        SettingsGroup("Updates") {
            SettingsRow("Kadr \(displayVersion)") {
                Button(action: checkForUpdates) {
                    HStack(spacing: EducaSpace.sm) {
                        if canCheckForUpdates {
                            Text("Check for Updates…")
                        } else {
                            ProgressView().controlSize(.small)
                            Text("Checking…")
                        }
                    }
                    .frame(minHeight: 40)
                }
                .disabled(!canCheckForUpdates)
            }
            SettingsRowDivider()
            SettingsRow("Automatically check for updates") {
                Toggle("Automatically check for updates", isOn: $automaticallyChecksForUpdates)
                    .toggleStyle(.switch)
                    .labelsHidden()
                    .frame(minHeight: 40)
            }
        } footer: {
            Text("Updates are delivered from GitHub and verified before installation.")
        }
    }
}
