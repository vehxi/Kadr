import AppKit
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct MovieEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.locale) private var locale
    @Environment(\.modelContext) private var modelContext
    @Query private var genres: [Genre]
    @Query private var allMovies: [Movie]

    private let movie: Movie?

    @State private var title: String
    @State private var mediaKind: MediaKind
    @State private var releaseYear: Int?
    @State private var releaseEndYear: Int?
    @State private var status: ViewingStatus
    @State private var isFavorite: Bool
    @State private var rating: Int?
    @State private var synopsis: String
    @State private var selectedGenreIDs: Set<UUID>
    @State private var pendingCoverData: Data?
    @State private var removesExistingCover = false
    @State private var seasonEpisodeCounts: [Int]

    @State private var showsFileImporter = false
    @State private var showsDuplicateWarning = false
    @State private var errorMessage: String?
    @State private var isSaving = false

    init(movie: Movie? = nil) {
        self.movie = movie
        _title = State(initialValue: movie?.title ?? "")
        _mediaKind = State(initialValue: movie?.mediaKind ?? .movie)
        _releaseYear = State(initialValue: movie?.releaseYear)
        _releaseEndYear = State(
            initialValue: movie?.mediaKind == .series
                ? (movie?.releaseEndYear ?? movie?.releaseYear)
                : nil
        )
        _status = State(initialValue: movie?.status ?? .wantToWatch)
        _isFavorite = State(initialValue: movie?.isFavorite ?? false)
        _rating = State(initialValue: movie?.rating)
        _synopsis = State(initialValue: movie?.synopsis ?? "")
        _selectedGenreIDs = State(initialValue: Set(movie?.genres.map(\.id) ?? []))
        let episodeCounts = movie?.sortedSeasons.map { $0.episodes.count } ?? []
        _seasonEpisodeCounts = State(initialValue: episodeCounts.isEmpty ? [10] : episodeCounts)
    }

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                HStack(alignment: .top, spacing: 32) {
                    coverSection
                    fields
                }
                .padding(32)
            }
            Divider()
            footer
        }
        .frame(minWidth: 860, idealWidth: 940, minHeight: 600, idealHeight: 680)
        .fileImporter(
            isPresented: $showsFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false,
            onCompletion: handleFileImport
        )
        .alert("Possible Duplicate", isPresented: $showsDuplicateWarning) {
            Button("Keep Editing", role: .cancel) {}
            Button("Save Anyway") {
                Task { await save() }
            }
        } message: {
            Text("A title with the same name and year already exists.")
        }
        .alert("Could Not Save Title", isPresented: errorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "")
        }
    }

    private var coverSection: some View {
        VStack(spacing: 14) {
            coverPreview
                .frame(width: 240, height: 360)
                .shadow(color: .black.opacity(0.14), radius: 12, y: 6)
                .dropDestination(for: URL.self) { urls, _ in
                    guard let url = urls.first else { return false }
                    Task { await loadImage(from: url) }
                    return true
                }
                .accessibilityLabel("Cover")
                .accessibilityHint("Drop an image file here")

            HStack(spacing: 2) {
                Button {
                    showsFileImporter = true
                } label: {
                    Image(systemName: "photo.badge.plus")
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help("Choose…")
                .accessibilityLabel("Choose…")

                Button {
                    pasteImage()
                } label: {
                    Image(systemName: "clipboard")
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .keyboardShortcut("v", modifiers: [.command, .shift])
                .help("Paste")
                .accessibilityLabel("Paste")

                if hasCover {
                    Button(role: .destructive) {
                        pendingCoverData = nil
                        removesExistingCover = true
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 40, height: 40)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .help("Remove Cover")
                    .accessibilityLabel("Remove Cover")
                }
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 5)
            .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

            Text("Choose, drop, or paste an image.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }

    @ViewBuilder
    private var coverPreview: some View {
        if let data = pendingCoverData, let image = NSImage(data: data) {
            GeometryReader { geometry in
                Image(nsImage: image)
                    .resizable()
                    .scaledToFill()
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(.primary.opacity(0.08))
                    }
            }
        } else if !removesExistingCover {
            PosterArtwork(title: title, filename: movie?.coverFilename, mediaKind: mediaKind)
        } else {
            PosterArtwork(title: title, filename: nil, mediaKind: mediaKind)
        }
    }

    private var fields: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center, spacing: 12) {
                Text(localized(movie == nil ? "Add Title" : "Edit Title"))
                    .font(.title2.weight(.semibold))
                    .tracking(-0.25)

                Spacer()

                Button {
                    isFavorite.toggle()
                } label: {
                    Image(systemName: isFavorite ? "heart.fill" : "heart")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(isFavorite ? .red : .secondary)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(localized(isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                .accessibilityLabel(localized(isFavorite ? "Remove from Favorites" : "Add to Favorites"))
                .accessibilityValue(localized(isFavorite ? "Favorite" : "Not Favorite"))
            }

            VStack(alignment: .leading, spacing: 8) {
                sectionTitle("Title")
                TextField("", text: $title, prompt: Text("Enter title"))
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .font(.title3.weight(.medium))
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                    .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Title")
            }
            .padding(.top, 12)

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    sectionTitle("Type")
                    Picker("Type", selection: mediaKindBinding) {
                        ForEach(MediaKind.allCases) { kind in
                            Label(kind.titleKey, systemImage: kind.systemImage)
                                .tag(kind)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.segmented)
                }
                .frame(minWidth: 210, maxWidth: .infinity, alignment: .leading)

                releaseYearsField
            }
            .padding(.top, 18)

            editorControlStrip
                .padding(.top, 18)

            genreSelector
                .padding(.top, 22)

            if mediaKind == .series {
                seriesEditor
                    .padding(.top, 22)
            }

            VStack(alignment: .leading, spacing: 9) {
                sectionTitle("Description")
                TextField(
                    "",
                    text: $synopsis,
                    prompt: Text("Add notes or a synopsis"),
                    axis: .vertical
                )
                    .labelsHidden()
                    .textFieldStyle(.plain)
                    .lineLimit(5...10)
                    .padding(12)
                    .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .accessibilityLabel("Description")
            }
            .padding(.top, 22)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var editorControlStrip: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 14) {
                Menu {
                    ForEach(ViewingStatus.allCases) { value in
                        Button {
                            statusBinding.wrappedValue = value
                        } label: {
                            Label(value.titleKey, systemImage: value.systemImage)
                        }
                    }
                } label: {
                    HStack(spacing: 7) {
                        Image(systemName: status.systemImage)
                        Text(status.titleKey)
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
                StarRating(rating: $rating)
            }
            .padding(.leading, 14)
            .padding(.trailing, 8)
            .frame(minHeight: 48)
            .background(.quaternary.opacity(0.38), in: RoundedRectangle(cornerRadius: 10, style: .continuous))

        }
    }

    private var genreSelector: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Genres")
            if genres.isEmpty {
                Text("Add genres in Settings.")
                    .foregroundStyle(.secondary)
            } else {
                FlowLayout(spacing: 7) {
                    ForEach(sortedGenres) { genre in
                        let isSelected = selectedGenreIDs.contains(genre.id)
                        Button {
                            if isSelected {
                                selectedGenreIDs.remove(genre.id)
                            } else {
                                selectedGenreIDs.insert(genre.id)
                            }
                        } label: {
                            HStack(spacing: 5) {
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.caption2.weight(.bold))
                                }
                                Text(genre.localizedName(locale: locale))
                            }
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 10)
                            .frame(minHeight: 40)
                            .background(
                                isSelected ? Color.accentColor.opacity(0.16) : Color.primary.opacity(0.06),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                }
            }
        }
    }

    private var sortedGenres: [Genre] {
        genres.sorted {
            $0.localizedName(locale: locale).localizedStandardCompare(
                $1.localizedName(locale: locale)
            ) == .orderedAscending
        }
    }

    private var seriesEditor: some View {
        VStack(alignment: .leading, spacing: 9) {
            sectionTitle("Seasons and Episodes")
            VStack(spacing: 0) {
                Stepper(value: seasonCountBinding, in: 1...50) {
                    HStack {
                        Text("Seasons")
                        Spacer()
                        Text(seasonEpisodeCounts.count, format: .number)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
                .padding(.horizontal, 12)
                .frame(minHeight: 44)

                ForEach(seasonEpisodeCounts.indices, id: \.self) { index in
                    Divider()
                        .padding(.leading, 12)
                    Stepper(value: episodeCountBinding(for: index), in: 1...100) {
                        HStack {
                            Text("Season \(index + 1)")
                            Spacer()
                            Text("\(seasonEpisodeCounts[index]) episodes")
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 44)
                }
            }
            .background(.quaternary.opacity(0.30), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
    }

    private func sectionTitle(_ key: LocalizedStringKey) -> some View {
        Text(key)
            .font(.caption.weight(.semibold))
            .foregroundStyle(.secondary)
            .textCase(.uppercase)
    }

    private var footer: some View {
        HStack {
            Spacer()
            Button("Cancel", role: .cancel) {
                dismiss()
            }
            .keyboardShortcut(.cancelAction)

            Button {
                attemptSave()
            } label: {
                if movie == nil {
                    Text("Add Title")
                } else {
                    Text("Save")
                }
            }
            .buttonStyle(.borderedProminent)
            .keyboardShortcut(.defaultAction)
            .disabled(!isValid || isSaving)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
    }

    private var hasCover: Bool {
        pendingCoverData != nil || (!removesExistingCover && movie?.coverFilename != nil)
    }

    private var isValid: Bool {
        !TextNormalizer.displayName(title).isEmpty
    }

    @ViewBuilder
    private var releaseYearsField: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle(mediaKind == .series ? "Release Period" : "Release Year")

            if mediaKind == .series {
                HStack(spacing: 12) {
                    yearPicker("From", selection: startYearBinding, years: availableYears)
                    yearPicker(
                        "To",
                        selection: $releaseEndYear,
                        years: availableEndYears,
                        isDisabled: releaseYear == nil,
                        allowsUnspecified: releaseYear == nil
                    )
                }
            } else {
                yearPicker("Release Year", selection: startYearBinding, years: availableYears)
                    .labelsHidden()
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func yearPicker(
        _ label: LocalizedStringKey,
        selection: Binding<Int?>,
        years: [Int],
        isDisabled: Bool = false,
        allowsUnspecified: Bool = true
    ) -> some View {
        Picker(label, selection: selection) {
            if allowsUnspecified {
                Text("Not Specified")
                    .tag(nil as Int?)
            }
            ForEach(years, id: \.self) { year in
                Text(year, format: .number.grouping(.never))
                    .monospacedDigit()
                    .tag(year as Int?)
            }
        }
        .pickerStyle(.menu)
        .frame(minWidth: 120, alignment: .leading)
        .disabled(isDisabled)
    }

    private var availableYears: [Int] {
        let currentYear = Calendar.current.component(.year, from: .now)
        var years = Set(1888...(currentYear + 10))
        if let releaseYear { years.insert(releaseYear) }
        if let releaseEndYear { years.insert(releaseEndYear) }
        return years.sorted(by: >)
    }

    private var availableEndYears: [Int] {
        guard let releaseYear else { return [] }
        return availableYears.filter { $0 >= releaseYear }
    }

    private var startYearBinding: Binding<Int?> {
        Binding(
            get: { releaseYear },
            set: { newYear in
                releaseYear = newYear
                guard mediaKind == .series, let newYear else {
                    releaseEndYear = nil
                    return
                }
                if releaseEndYear == nil || releaseEndYear.map({ $0 < newYear }) == true {
                    releaseEndYear = newYear
                }
            }
        )
    }

    private var statusBinding: Binding<ViewingStatus> {
        Binding(
            get: { status },
            set: { newStatus in
                status = newStatus
            }
        )
    }

    private var mediaKindBinding: Binding<MediaKind> {
        Binding(
            get: { mediaKind },
            set: { newKind in
                mediaKind = newKind
                if newKind == .series {
                    releaseEndYear = releaseEndYear ?? releaseYear
                } else {
                    releaseEndYear = nil
                }
            }
        )
    }

    private var seasonCountBinding: Binding<Int> {
        Binding(
            get: { seasonEpisodeCounts.count },
            set: { newCount in
                if newCount > seasonEpisodeCounts.count {
                    seasonEpisodeCounts.append(
                        contentsOf: repeatElement(10, count: newCount - seasonEpisodeCounts.count)
                    )
                } else if newCount < seasonEpisodeCounts.count {
                    seasonEpisodeCounts.removeLast(seasonEpisodeCounts.count - newCount)
                }
            }
        )
    }

    private func episodeCountBinding(for index: Int) -> Binding<Int> {
        Binding(
            get: { seasonEpisodeCounts[index] },
            set: { seasonEpisodeCounts[index] = $0 }
        )
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

    private func attemptSave() {
        let candidates = allMovies.map {
            DuplicateCandidate(id: $0.id, title: $0.title, releaseYear: $0.releaseYear)
        }
        if DuplicateDetector.containsDuplicate(
            title: title,
            releaseYear: releaseYear,
            excluding: movie?.id,
            in: candidates
        ) {
            showsDuplicateWarning = true
        } else {
            Task { await save() }
        }
    }

    @MainActor
    private func save() async {
        guard isValid else { return }
        isSaving = true
        defer { isSaving = false }

        let previousFilename = movie?.coverFilename
        var newlyWrittenFilename: String?

        do {
            let coverFilename: String?
            if let pendingCoverData {
                newlyWrittenFilename = try await CoverStore.shared.write(pendingCoverData)
                coverFilename = newlyWrittenFilename
            } else if removesExistingCover {
                coverFilename = nil
            } else {
                coverFilename = previousFilename
            }

            let selectedGenres = genres.filter { selectedGenreIDs.contains($0.id) }
            if let movie {
                movie.update(
                    title: title,
                    mediaKind: mediaKind,
                    releaseYear: releaseYear,
                    releaseEndYear: releaseEndYear,
                    status: status,
                    isFavorite: isFavorite,
                    rating: rating,
                    synopsis: synopsis,
                    coverFilename: coverFilename,
                    genres: selectedGenres
                )
                syncSeriesStructure(for: movie)
            } else {
                let newMovie = Movie(
                    title: title,
                    mediaKind: mediaKind,
                    releaseYear: releaseYear,
                    releaseEndYear: releaseEndYear,
                    status: status,
                    isFavorite: isFavorite,
                    rating: rating,
                    synopsis: synopsis,
                    coverFilename: coverFilename,
                    genres: selectedGenres
                )
                modelContext.insert(newMovie)
                syncSeriesStructure(for: newMovie)
            }
            try modelContext.save()

            if previousFilename != coverFilename {
                try? await CoverStore.shared.delete(filename: previousFilename)
            }
            dismiss()
        } catch {
            modelContext.rollback()
            try? await CoverStore.shared.delete(filename: newlyWrittenFilename)
            errorMessage = error.localizedDescription
        }
    }

    private func syncSeriesStructure(for movie: Movie) {
        guard mediaKind == .series else {
            movie.seasons.forEach(modelContext.delete)
            movie.seasons.removeAll()
            return
        }

        let existingSeasons = Dictionary(uniqueKeysWithValues: movie.seasons.map { ($0.number, $0) })
        let desiredNumbers = Set(1...seasonEpisodeCounts.count)

        for season in movie.seasons where !desiredNumbers.contains(season.number) {
            modelContext.delete(season)
        }

        var updatedSeasons: [SeriesSeason] = []
        for (index, desiredEpisodeCount) in seasonEpisodeCounts.enumerated() {
            let seasonNumber = index + 1
            let season = existingSeasons[seasonNumber] ?? SeriesSeason(number: seasonNumber)
            if existingSeasons[seasonNumber] == nil {
                modelContext.insert(season)
            }
            season.movie = movie

            let existingEpisodes = Dictionary(
                uniqueKeysWithValues: season.episodes.map { ($0.number, $0) }
            )
            let desiredEpisodeNumbers = Set(1...desiredEpisodeCount)
            for episode in season.episodes where !desiredEpisodeNumbers.contains(episode.number) {
                modelContext.delete(episode)
            }

            season.episodes = (1...desiredEpisodeCount).map { episodeNumber in
                if let episode = existingEpisodes[episodeNumber] {
                    return episode
                }
                let episode = SeriesEpisode(number: episodeNumber, season: season)
                modelContext.insert(episode)
                return episode
            }
            updatedSeasons.append(season)
        }
        movie.seasons = updatedSeasons
    }

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task { await loadImage(from: url) }
        case .failure(let error):
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadImage(from url: URL) async {
        let hasAccess = url.startAccessingSecurityScopedResource()
        defer {
            if hasAccess {
                url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            let data = try Data(contentsOf: url)
            pendingCoverData = try await Task.detached {
                try ImageProcessor.normalizedJPEGData(from: data)
            }.value
            removesExistingCover = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func pasteImage() {
        guard let image = NSImage(pasteboard: NSPasteboard.general),
              let data = image.tiffRepresentation
        else {
            errorMessage = String(localized: "The clipboard does not contain an image.")
            return
        }

        Task { @MainActor in
            do {
                pendingCoverData = try await Task.detached {
                    try ImageProcessor.normalizedJPEGData(from: data)
                }.value
                removesExistingCover = false
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}
