import SwiftData
import SwiftUI

struct MovieDetailView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext

    let movie: Movie

    @State private var showsEditor = false
    @State private var showsDeleteConfirmation = false
    @State private var pendingStatus: ViewingStatus?
    @State private var showsRatingRemovalWarning = false
    @State private var errorMessage: String?
    @State private var heartIsPressed = false

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 32) {
                    PosterArtwork(
                        title: movie.title,
                        filename: movie.coverFilename,
                        mediaKind: movie.mediaKind
                    )
                        .frame(width: 250, height: 375)
                        .shadow(color: .black.opacity(0.14), radius: 12, y: 6)

                    details
                }
                .padding(32)
            }

            Divider()
            actions
        }
        .frame(minWidth: 820, idealWidth: 900, minHeight: 500, idealHeight: 500)
        .sheet(isPresented: $showsEditor) {
            MovieEditorView(movie: movie)
                .environment(\.locale, locale)
        }
        .alert(
            localized(movie.mediaKind == .series ? "Delete Series?" : "Delete Movie?"),
            isPresented: $showsDeleteConfirmation
        ) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                Task { await deleteMovie() }
            }
        } message: {
            Text("This title, its viewing progress, and its local cover copy will be permanently deleted.")
        }
        .alert("Remove Rating?", isPresented: $showsRatingRemovalWarning) {
            Button("Cancel", role: .cancel) {
                pendingStatus = nil
            }
            Button("Change Status", role: .destructive) {
                applyPendingStatus()
            }
        } message: {
            Text("Ratings are only available for watched titles. Changing the status will clear this rating.")
        }
        .alert("Could Not Complete the Action", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .top, spacing: 16) {
                VStack(alignment: .leading, spacing: 7) {
                    Text(movie.title)
                        .font(.largeTitle.weight(.semibold))
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                        .textSelection(.enabled)

                    HStack(spacing: 8) {
                        Label(movie.mediaKind.titleKey, systemImage: movie.mediaKind.systemImage)
                        if let releasePeriodText = movie.releasePeriodText {
                            Text("•")
                                .foregroundStyle(.quaternary)
                            Text(releasePeriodText)
                                .monospacedDigit()
                        }
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)
                headerActions
            }

            controlStrip
                .padding(.top, 22)

            if !movie.genres.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("Genres")
                    FlowLayout(spacing: 7) {
                        ForEach(movie.genres.sorted { $0.name < $1.name }) { genre in
                            Text(genre.name)
                                .font(.caption.weight(.medium))
                                .padding(.horizontal, 9)
                                .padding(.vertical, 5)
                                .background(.quaternary.opacity(0.55), in: Capsule())
                        }
                    }
                }
                .padding(.top, 20)
            }

            if movie.mediaKind == .series {
                seriesProgress
                    .padding(.top, 20)
            }

            if !movie.synopsis.isEmpty {
                VStack(alignment: .leading, spacing: 9) {
                    sectionTitle("Description")
                    Text(movie.synopsis)
                        .font(.body)
                        .lineSpacing(2)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.top, 22)
            }

            Spacer(minLength: 24)

            HStack(spacing: 16) {
                Text("Added \(movie.createdAt, format: .dateTime.day().month().year())")
                Text("Updated \(movie.updatedAt, format: .dateTime.day().month().year())")
            }
            .font(.caption)
            .foregroundStyle(.tertiary)
            .monospacedDigit()
        }
        .frame(maxWidth: .infinity, minHeight: 375, alignment: .topLeading)
    }

    private var headerActions: some View {
        HStack(spacing: 2) {
            Button(action: toggleFavorite) {
                Image(systemName: movie.isFavorite ? "heart.fill" : "heart")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(movie.isFavorite ? .red : .secondary)
                    .scaleEffect(heartIsPressed ? 1.14 : 1)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help(localized(movie.isFavorite ? "Remove from Favorites" : "Add to Favorites"))
            .accessibilityLabel(localized(movie.isFavorite ? "Remove from Favorites" : "Add to Favorites"))
            .accessibilityValue(localized(movie.isFavorite ? "Favorite" : "Not Favorite"))

            Button {
                showsEditor = true
            } label: {
                Image(systemName: "pencil")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .help("Edit")
            .accessibilityLabel("Edit")

            Menu {
                Button(role: .destructive) {
                    showsDeleteConfirmation = true
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 40, height: 40)
                    .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("More")
            .accessibilityLabel("More")
        }
    }

    private var controlStrip: some View {
        HStack(spacing: 14) {
            Menu {
                ForEach(ViewingStatus.allCases) { status in
                    Button {
                        statusBinding.wrappedValue = status
                    } label: {
                        Label(status.titleKey, systemImage: status.systemImage)
                    }
                }
            } label: {
                HStack(spacing: 7) {
                    Image(systemName: movie.status.systemImage)
                    Text(movie.status.titleKey)
                        .lineLimit(1)
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
                .font(.subheadline.weight(.medium))
                .contentShape(Rectangle())
            }
            .menuStyle(.borderlessButton)
            .fixedSize()
            .accessibilityLabel("Status")

            Spacer(minLength: 10)

            StarRating(
                rating: ratingBinding,
                isEnabled: movie.status.allowsRating
            )
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(minHeight: 48)
        .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var seriesProgress: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Episode Progress")
                    .font(.headline)
                Spacer()
                Text("\(movie.watchedEpisodeCount) of \(movie.episodeCount)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }

            ProgressView(
                value: Double(movie.watchedEpisodeCount),
                total: Double(max(movie.episodeCount, 1))
            )
            .accessibilityLabel("Episode Progress")
            .accessibilityValue("\(movie.watchedEpisodeCount) of \(movie.episodeCount) episodes watched")

            ForEach(movie.sortedSeasons) { season in
                DisclosureGroup {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Spacer()
                            Button(
                                season.watchedEpisodeCount == season.episodes.count
                                    ? localized("Mark Unwatched")
                                    : localized("Mark All Watched")
                            ) {
                                setSeason(season, watched: season.watchedEpisodeCount != season.episodes.count)
                            }
                            .buttonStyle(.borderless)
                        }

                        ForEach(season.sortedEpisodes) { episode in
                            Toggle(isOn: episodeBinding(episode)) {
                                HStack {
                                    Text("Episode \(episode.number)")
                                    if !episode.title.isEmpty {
                                        Text(episode.title)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(1)
                                    }
                                }
                            }
                            .toggleStyle(.checkbox)
                        }
                    }
                    .padding(.top, 8)
                } label: {
                    HStack {
                        Text("Season \(season.number)")
                            .font(.subheadline.weight(.medium))
                        Spacer()
                        Text("\(season.watchedEpisodeCount)/\(season.episodes.count)")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var actions: some View {
        HStack {
            Spacer()
            Button("Done") {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)
            .buttonStyle(.borderedProminent)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var statusBinding: Binding<ViewingStatus> {
        Binding(
            get: { movie.status },
            set: { newStatus in
                if movie.rating != nil, !newStatus.allowsRating {
                    pendingStatus = newStatus
                    showsRatingRemovalWarning = true
                } else {
                    movie.status = newStatus
                    saveChanges()
                }
            }
        )
    }

    private var ratingBinding: Binding<Int?> {
        Binding(
            get: { movie.rating },
            set: { newValue in
                movie.rating = RatingRules.validated(newValue, for: movie.status)
                movie.updatedAt = .now
                saveChanges()
            }
        )
    }

    private func episodeBinding(_ episode: SeriesEpisode) -> Binding<Bool> {
        Binding(
            get: { episode.isWatched },
            set: { isWatched in
                episode.isWatched = isWatched
                episode.watchedAt = isWatched ? .now : nil
                updateStatusFromEpisodeProgress()
                saveChanges()
            }
        )
    }

    private func setSeason(_ season: SeriesSeason, watched: Bool) {
        for episode in season.episodes {
            episode.isWatched = watched
            episode.watchedAt = watched ? .now : nil
        }
        updateStatusFromEpisodeProgress()
        saveChanges()
    }

    private func updateStatusFromEpisodeProgress() {
        guard movie.status != .abandoned else { return }
        if movie.episodeCount > 0, movie.watchedEpisodeCount == movie.episodeCount {
            movie.status = .watched
        } else if movie.watchedEpisodeCount > 0, movie.status == .wantToWatch {
            movie.status = .watching
        }
    }

    private var errorBinding: Binding<Bool> {
        Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )
    }

    private func localized(_ key: String) -> String {
        AppLocalization.string(key, locale: locale)
    }

    private func toggleFavorite() {
        movie.isFavorite.toggle()
        saveChanges()

        guard !reduceMotion else { return }
        withAnimation(.easeOut(duration: 0.08)) {
            heartIsPressed = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(80))
            withAnimation(.easeOut(duration: 0.12)) {
                heartIsPressed = false
            }
        }
    }

    private func applyPendingStatus() {
        guard let pendingStatus else { return }
        movie.status = pendingStatus
        movie.rating = nil
        self.pendingStatus = nil
        saveChanges()
    }

    private func saveChanges() {
        movie.updatedAt = .now
        do {
            try modelContext.save()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func deleteMovie() async {
        let filename = movie.coverFilename
        do {
            modelContext.delete(movie)
            try modelContext.save()
            try await CoverStore.shared.delete(filename: filename)
            dismiss()
        } catch {
            modelContext.rollback()
            errorMessage = error.localizedDescription
        }
    }
}
