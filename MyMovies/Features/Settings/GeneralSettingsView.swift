import SwiftUI

struct GeneralSettingsView: View {
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                SettingsSectionTitle("Language", systemImage: "globe")

                SettingsSurface(isInteractive: true) {
                    HStack(spacing: 16) {
                        SettingsIcon(systemImage: "character.bubble")

                        VStack(alignment: .leading, spacing: 3) {
                            Text("Application Language")
                                .font(.headline)
                            Text("The app content changes immediately. Some system menu items may require reopening the app.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        Spacer(minLength: 16)

                        Picker("Application Language", selection: $appLanguageRawValue) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.titleKey)
                                    .tag(language.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 150)
                    }
                }

                SettingsSectionTitle("Storage", systemImage: "internaldrive")

                SettingsSurface {
                    VStack(spacing: 0) {
                        storageRow(
                            title: "Database",
                            value: "Application Support",
                            systemImage: "cylinder"
                        )

                        Divider()
                            .padding(.leading, 48)

                        storageRow(
                            title: "Covers",
                            value: "Application Support/My Movies/Covers",
                            systemImage: "photo.on.rectangle"
                        )

                        Divider()
                            .padding(.leading, 48)

                        Label(
                            "All information stays on this Mac. iCloud and online services are not used.",
                            systemImage: "lock.fill"
                        )
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 12)
                    }
                }
            }
            .padding(24)
        }
    }

    private func storageRow(
        title: LocalizedStringKey,
        value: LocalizedStringKey,
        systemImage: String
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: systemImage)
                .foregroundStyle(.secondary)
                .frame(width: 28)

            Text(title)
                .font(.headline)

            Spacer(minLength: 16)

            Text(value)
                .font(.callout)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
                .lineLimit(1)
                .truncationMode(.middle)
        }
        .frame(minHeight: 44)
    }
}

struct SettingsSectionTitle: View {
    let title: LocalizedStringKey
    let systemImage: String

    init(_ title: LocalizedStringKey, systemImage: String) {
        self.title = title
        self.systemImage = systemImage
    }

    var body: some View {
        Label(title, systemImage: systemImage)
            .font(.title3.weight(.semibold))
            .foregroundStyle(.primary)
    }
}

struct SettingsIcon: View {
    let systemImage: String

    var body: some View {
        Image(systemName: systemImage)
            .font(.title3.weight(.medium))
            .foregroundStyle(.tint)
            .frame(width: 36, height: 36)
            .background(Color.accentColor.opacity(0.12), in: Circle())
            .accessibilityHidden(true)
    }
}

struct SettingsSurface<Content: View>: View {
    let isInteractive: Bool
    let content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    init(
        isInteractive: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                Color(nsColor: .controlBackgroundColor),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
            .shadow(
                color: .black.opacity(isHovering ? 0.16 : 0.09),
                radius: isHovering ? 8 : 4,
                y: isHovering ? 4 : 2
            )
            .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.16),
                value: isHovering
            )
            .onHover { isHovering = isInteractive && $0 }
    }
}
