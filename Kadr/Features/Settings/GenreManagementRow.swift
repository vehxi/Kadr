import SwiftUI

struct GenreManagementRow: View {
    let genre: Genre
    let displayName: String
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var name: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    init(
        genre: Genre,
        displayName: String,
        onRename: @escaping (String) -> Void,
        onDelete: @escaping () -> Void
    ) {
        self.genre = genre
        self.displayName = displayName
        self.onRename = onRename
        self.onDelete = onDelete
        _name = State(initialValue: displayName)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "tag.fill")
                .foregroundStyle(.tint)
                .frame(width: 28, height: 28)
                .background(Color.accentColor.opacity(0.12), in: Circle())
                .accessibilityHidden(true)

            TextField("Genre Name", text: $name)
                .onSubmit {
                    onRename(name)
                }

            Text(genre.movies.count, format: .number)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .trailing)
                .help("Number of Movies")

            Button {
                onRename(name)
            } label: {
                Image(systemName: "checkmark")
            }
            .buttonStyle(.borderless)
            .disabled(
                TextNormalizer.displayName(name).isEmpty
                    || TextNormalizer.displayName(name) == displayName
            )
            .accessibilityLabel("Save Genre Name")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
            .accessibilityLabel("Delete Genre")
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 52)
        .background(
            Color(nsColor: .controlBackgroundColor),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
        )
        .shadow(
            color: .black.opacity(isHovering ? 0.14 : 0.07),
            radius: isHovering ? 7 : 3,
            y: isHovering ? 4 : 2
        )
        .scaleEffect(isHovering && !reduceMotion ? 1.01 : 1)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovering
        )
        .onHover { isHovering = $0 }
        .onChange(of: displayName) { _, newValue in
            name = newValue
        }
    }
}
