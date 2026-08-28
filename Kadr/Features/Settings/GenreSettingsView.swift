import SwiftData
import SwiftUI

struct GenreSettingsView: View {
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Query private var genres: [Genre]

    @State private var newGenreName = ""
    @State private var genreToDelete: Genre?
    @State private var message: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SettingsSectionTitle("Genres", systemImage: "tag")

                SettingsSurface(isInteractive: true) {
                    HStack(spacing: 12) {
                        SettingsIcon(systemImage: "plus")

                        TextField("New Genre", text: $newGenreName)
                            .textFieldStyle(.roundedBorder)
                            .onSubmit(addGenre)

                        Button("Add", action: addGenre)
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)
                            .disabled(TextNormalizer.displayName(newGenreName).isEmpty)
                    }
                }

                if genres.isEmpty {
                    ContentUnavailableView(
                        "No Genres",
                        systemImage: "tag",
                        description: Text("Add a genre to use it in movie forms.")
                    )
                    .frame(maxWidth: .infinity, minHeight: 260)
                } else {
                    LazyVStack(spacing: 10) {
                        ForEach(sortedGenres) { genre in
                            GenreManagementRow(
                                genre: genre,
                                displayName: genre.localizedName(locale: locale),
                                onRename: { rename(genre, to: $0) },
                                onDelete: { genreToDelete = genre }
                            )
                        }
                    }
                }
            }
            .padding(24)
        }
        .alert(
            "Delete Genre?",
            isPresented: deleteConfirmationBinding,
            presenting: genreToDelete
        ) { genre in
            Button("Cancel", role: .cancel) {
                genreToDelete = nil
            }
            Button("Delete", role: .destructive) {
                delete(genre)
            }
        } message: { genre in
            Text(deleteMessage(for: genre))
        }
        .alert("Genres", isPresented: messageBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(message ?? "")
        }
    }

    private var deleteConfirmationBinding: Binding<Bool> {
        Binding(
            get: { genreToDelete != nil },
            set: { if !$0 { genreToDelete = nil } }
        )
    }

    private var messageBinding: Binding<Bool> {
        Binding(
            get: { message != nil },
            set: { if !$0 { message = nil } }
        )
    }

    private func addGenre() {
        let displayName = TextNormalizer.displayName(newGenreName)
        guard !displayName.isEmpty else { return }
        guard !GenreRules.isDuplicate(name: displayName, among: genrePairs) else {
            message = String(localized: "A genre with this name already exists.")
            return
        }

        do {
            modelContext.insert(Genre(name: displayName))
            try modelContext.save()
            newGenreName = ""
        } catch {
            modelContext.rollback()
            message = error.localizedDescription
        }
    }

    private func rename(_ genre: Genre, to name: String) {
        let displayName = TextNormalizer.displayName(name)
        guard !displayName.isEmpty else { return }
        guard !GenreRules.isDuplicate(
            name: displayName,
            excluding: genre.id,
            among: genrePairs
        ) else {
            message = String(localized: "A genre with this name already exists.")
            return
        }

        do {
            genre.rename(to: displayName)
            try modelContext.save()
        } catch {
            modelContext.rollback()
            message = error.localizedDescription
        }
    }

    private func delete(_ genre: Genre) {
        do {
            modelContext.delete(genre)
            try modelContext.save()
            genreToDelete = nil
        } catch {
            modelContext.rollback()
            message = error.localizedDescription
        }
    }

    private var genrePairs: [(id: UUID, name: String)] {
        genres.map { ($0.id, $0.localizedName(locale: locale)) }
    }

    private var sortedGenres: [Genre] {
        genres.sorted {
            $0.localizedName(locale: locale).localizedStandardCompare(
                $1.localizedName(locale: locale)
            ) == .orderedAscending
        }
    }

    private func deleteMessage(for genre: Genre) -> String {
        if genre.movies.isEmpty {
            return String(localized: "This genre will be permanently deleted.")
        }
        return String(
            localized: "This genre will be removed from \(genre.movies.count) movies. The movies themselves will not be deleted."
        )
    }
}
