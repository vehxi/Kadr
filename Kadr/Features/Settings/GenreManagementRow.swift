import SwiftUI

struct GenreManagementRow: View {
    let genre: Genre
    let displayName: String
    let onRename: (String) -> Void
    let onDelete: () -> Void

    @State private var name: String

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
            Image(systemName: "tag")
                .foregroundStyle(EducaColor.secondaryText)
                .frame(width: 20)
                .accessibilityHidden(true)

            TextField("Genre Name", text: $name)
                .textFieldStyle(EducaTextFieldStyle())
                .onSubmit {
                    onRename(name)
                }

            Text(genre.movies.count, format: .number)
                .foregroundStyle(EducaColor.secondaryText)
                .monospacedDigit()
                .frame(minWidth: 28, alignment: .trailing)
                .help("Number of Movies")

            Button {
                onRename(name)
            } label: {
                Image(systemName: "checkmark")
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(EducaButtonStyle(kind: .icon))
            .disabled(
                TextNormalizer.displayName(name).isEmpty
                    || TextNormalizer.displayName(name) == displayName
            )
            .accessibilityLabel("Save Genre Name")
            .help("Save Genre Name")

            Button(role: .destructive, action: onDelete) {
                Image(systemName: "trash")
                    .foregroundStyle(.red)
                    .frame(width: 40, height: 40)
            }
            .buttonStyle(EducaButtonStyle(kind: .icon))
            .accessibilityLabel("Delete Genre")
            .help("Delete Genre")
        }
        .padding(.horizontal, EducaSpace.md)
        .padding(.vertical, EducaSpace.sm)
        .onChange(of: displayName) { _, newValue in
            name = newValue
        }
    }
}
