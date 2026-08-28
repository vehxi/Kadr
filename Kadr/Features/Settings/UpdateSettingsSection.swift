import SwiftUI

struct UpdateSettingsSection: View {
    @ObservedObject var updateController: UpdateController

    var body: some View {
        SettingsSectionTitle("Updates", systemImage: "arrow.triangle.2.circlepath")

        SettingsSurface(isInteractive: true) {
            VStack(spacing: 0) {
                updateRow

                Divider()
                    .padding(.leading, 48)
                    .padding(.vertical, 10)

                Toggle(
                    "Automatically check for updates",
                    isOn: $updateController.automaticallyChecksForUpdates
                )
                    .toggleStyle(.switch)
                    .frame(minHeight: 40)
            }
        }
    }

    private var updateRow: some View {
        HStack(spacing: 16) {
            SettingsIcon(systemImage: "arrow.triangle.2.circlepath")

            VStack(alignment: .leading, spacing: 3) {
                Text("Kadr \(updateController.displayVersion)")
                    .font(.headline)
                Text("Updates are delivered from GitHub and verified before installation.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 16)

            UpdateCheckButton(updateController: updateController)
        }
    }
}

private struct UpdateCheckButton: View {
    @ObservedObject var updateController: UpdateController

    var body: some View {
        Button {
            updateController.checkForUpdates()
        } label: {
            buttonLabel
                .frame(minWidth: 146)
        }
        .disabled(!updateController.canCheckForUpdates)
        .frame(minHeight: 40)
    }

    @ViewBuilder
    private var buttonLabel: some View {
        if updateController.canCheckForUpdates {
            Label("Check for Updates…", systemImage: "arrow.triangle.2.circlepath")
        } else {
            HStack(spacing: 7) {
                ProgressView()
                    .controlSize(.small)
                Text("Checking…")
            }
        }
    }
}
