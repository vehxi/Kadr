import SwiftUI

struct ProductionCountrySelector: View {
    @Binding var selection: Set<String>
    @Environment(\.locale) private var locale
    @State private var isPresented = false
    @State private var search = ""
    @FocusState private var searchIsFocused: Bool

    private var filteredCodes: [String] {
        let query = TextNormalizer.normalize(search)
        return ProductionCountries.sortedCodes(locale: locale).filter {
            query.isEmpty || TextNormalizer.normalize(ProductionCountries.name(for: $0, locale: locale)).contains(query)
                || $0.lowercased().contains(query)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            if selection.isEmpty {
                Text("No production countries selected.")
                    .foregroundStyle(EducaColor.secondaryText)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(ProductionCountries.sortedCodes(locale: locale).filter { selection.contains($0) }, id: \.self) { code in
                        Text(ProductionCountries.name(for: code, locale: locale))
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 9)
                            .padding(.vertical, 5)
                            .background(EducaColor.secondaryButton, in: Capsule())
                    }
                }
            }
            Button {
                search = ""
                isPresented = true
            } label: {
                Label("Choose Countries…", systemImage: "globe.europe.africa")
            }
            .popover(isPresented: $isPresented, arrowEdge: .bottom) {
                VStack(spacing: 0) {
                    TextField("Search Countries", text: $search)
                        .textFieldStyle(EducaTextFieldStyle())
                        .focused($searchIsFocused)
                        .padding(12)
                    EducaDivider()
                    if filteredCodes.isEmpty {
                        ContentUnavailableView("No Countries Found", systemImage: "magnifyingglass", description: Text("Try another search."))
                    } else {
                        List(filteredCodes, id: \.self) { code in
                            Toggle(ProductionCountries.name(for: code, locale: locale), isOn: Binding(
                                get: { selection.contains(code) },
                                set: { if $0 { selection.insert(code) } else { selection.remove(code) } }
                            ))
                            .toggleStyle(.checkbox)
                            .frame(minHeight: 40)
                        }
                        .listStyle(.inset)
                        .scrollContentBackground(.hidden)
                    }
                    EducaDivider()
                    HStack {
                        Text("\(selection.count) selected").font(.caption).foregroundStyle(EducaColor.secondaryText)
                        Spacer()
                        Button("Done") { isPresented = false }
                            .buttonStyle(EducaButtonStyle())
                            .keyboardShortcut(.cancelAction)
                    }
                    .padding(12)
                }
                .frame(width: 340, height: 420)
                .background(EducaColor.panel)
                .environment(\.locale, locale)
                .onExitCommand { isPresented = false }
                .task {
                    await Task.yield()
                    guard !Task.isCancelled else { return }
                    searchIsFocused = true
                }
            }
            .transaction(value: isPresented) { transaction in
                // macOS 27's animated NSPopover teardown can re-enter a CA commit.
                if #available(macOS 27, *) {
                    transaction.disablesAnimations = true
                }
            }
        }
    }
}
