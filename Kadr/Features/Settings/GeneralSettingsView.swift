import SwiftUI

struct GeneralSettingsView: View {
    @ObservedObject var updateController: UpdateController
    @AppStorage("appLanguage") private var appLanguage = AppLanguage.system.rawValue
    @AppStorage("appAppearance") private var appearance = AppAppearance.system.rawValue

    var body: some View {
        GeneralSettingsContent(appearance: $appearance, appLanguage: $appLanguage) {
            UpdateSettingsSection(updateController: updateController)
        }
    }
}

/// Keep the layout independent of Sparkle: rendering fixtures never start an updater.
struct GeneralSettingsContent<Updates: View>: View {
    @Binding var appearance: String
    @Binding var appLanguage: String
    @ViewBuilder let updates: () -> Updates

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: EducaSpace.panel) {
                SettingsGroup("Appearance") {
                    SettingsRow("Application Theme") {
                        Picker("Application Theme", selection: $appearance) {
                            Text("System").tag(AppAppearance.system.rawValue)
                            Text("Light").tag(AppAppearance.light.rawValue)
                            Text("Dark").tag(AppAppearance.dark.rawValue)
                        }
                        .pickerStyle(.segmented)
                        .labelsHidden()
                        .frame(width: 280)
                        .frame(minHeight: 40)
                    }
                    SettingsRowDivider()
                    SettingsRow("Application Language") {
                        Picker("Application Language", selection: $appLanguage) {
                            ForEach(AppLanguage.allCases) { language in
                                Text(language.titleKey).tag(language.rawValue)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 180)
                        .frame(minHeight: 40)
                    }
                } footer: {
                    Text("The app content changes immediately. Some system menu items may require reopening the app.")
                }

                updates()

                SettingsGroup("Storage") {
                    SettingsRow("Database") {
                        storagePath("Application Support")
                    }
                    SettingsRowDivider()
                    SettingsRow("Covers") {
                        storagePath("Application Support/Kadr/Covers")
                    }
                } footer: {
                    Label("All information stays on this Mac. iCloud and online services are not used.", systemImage: "lock")
                }
            }
            .padding(EducaSpace.panel)
        }
    }

    private func storagePath(_ path: LocalizedStringKey) -> some View {
        Text(path)
            .foregroundStyle(EducaColor.secondaryText)
            .textSelection(.enabled)
            .lineLimit(1)
            .truncationMode(.middle)
    }
}

/// Quiet grouped preferences instead of elevated dashboard cards.
struct SettingsGroup<Content: View, Footer: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content
    @ViewBuilder let footer: () -> Footer

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content,
         @ViewBuilder footer: @escaping () -> Footer) {
        self.title = title
        self.content = content
        self.footer = footer
    }

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) where Footer == EmptyView {
        self.init(title, content: content, footer: { EmptyView() })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EducaSpace.sm) {
            Text(title)
                .font(EducaType.control.weight(.semibold))
                .padding(.horizontal, EducaSpace.md)

            VStack(spacing: 0, content: content)
                .background(EducaColor.panel, in: RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: EducaRadius.button, style: .continuous)
                        .strokeBorder(EducaColor.border)
                        .allowsHitTesting(false)
                }

            footer()
                .font(EducaType.caption)
                .foregroundStyle(EducaColor.secondaryText)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, EducaSpace.md)
        }
    }
}

struct SettingsRow<Content: View>: View {
    let title: LocalizedStringKey
    @ViewBuilder let content: () -> Content

    init(_ title: LocalizedStringKey, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        HStack(alignment: .center, spacing: EducaSpace.lg) {
            Text(title)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)
            Spacer(minLength: 0)
            content()
        }
        .font(EducaType.control)
        .frame(minHeight: 40)
        .padding(.horizontal, EducaSpace.lg)
        .padding(.vertical, EducaSpace.xs)
    }
}

struct SettingsRowDivider: View {
    var body: some View {
        EducaDivider().padding(.horizontal, EducaSpace.lg)
    }
}
