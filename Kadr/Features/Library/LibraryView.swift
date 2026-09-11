import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @Query(sort: \Movie.updatedAt, order: .reverse) private var movies: [Movie]

    @State private var selection: LibraryFilter? = .all
    @State private var navigationPath: [UUID] = []
    @State private var showsAddEditor = false
    @State private var startupError: String?

    private let grid = [
        GridItem(.adaptive(minimum: 148, maximum: 210), spacing: 28, alignment: .top)
    ]

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 190, ideal: 220, max: 280)
        } detail: {
            NavigationStack(path: $navigationPath) {
                content
                    .navigationTitle(selectionTitle)
                    .background(WindowTitleUpdater(title: selectionTitle))
                    .toolbar {
                        ToolbarItem(placement: .primaryAction) {
                            Button {
                                presentAddMovie()
                            } label: {
                                Label("Add Title", systemImage: "plus")
                            }
                            .keyboardShortcut("n", modifiers: .command)
                            .help("Add Title")
                        }
                    }
                    .navigationDestination(for: UUID.self) { movieID in
                        if let movie = movie(withID: movieID) {
                            MovieDetailView(movie: movie) {
                                navigationPath.removeAll()
                            }
                            .navigationTitle(movie.title)
                        }
                    }
            }
        }
        .navigationSplitViewStyle(.balanced)
        .sheet(isPresented: $showsAddEditor) {
            MovieEditorView()
                .environment(\.locale, locale)
        }
        .onReceive(NotificationCenter.default.publisher(for: .newMovieRequested)) { _ in
            presentAddMovie()
        }
        .task {
            do {
                try PersistenceController.migrateLegacyFavorites(in: modelContext)
                let language = AppLanguage(rawValue: appLanguageRawValue) ?? .system
                try InitialGenreSeeder.seedIfNeeded(context: modelContext, language: language)
            } catch {
                startupError = error.localizedDescription
            }
        }
        .alert("Could Not Prepare the Library", isPresented: startupErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(startupError ?? "")
        }
        .onChange(of: selection) {
            navigationPath.removeAll()
        }
        .onChange(of: movies.map(\.id)) { _, movieIDs in
            if navigationPath.contains(where: { !movieIDs.contains($0) }) {
                navigationPath.removeAll()
            }
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Label {
                    sidebarLabel("All Titles", count: movies.count)
                } icon: {
                    Image(systemName: "rectangle.stack")
                }
                .tag(LibraryFilter.all)

                Label {
                    sidebarLabel("Movies", count: movieCount)
                } icon: {
                    Image(systemName: MediaKind.movie.systemImage)
                }
                .tag(LibraryFilter.movies)

                Label {
                    sidebarLabel("Series", count: seriesCount)
                } icon: {
                    Image(systemName: MediaKind.series.systemImage)
                }
                .tag(LibraryFilter.series)

                Label {
                    sidebarLabel("Favorite", count: favoriteCount)
                } icon: {
                    Image(systemName: "heart.fill")
                }
                .tag(LibraryFilter.favorites)

                Label("Tier List", systemImage: "square.grid.3x3.square")
                    .tag(LibraryFilter.tierList)

                Section("Status") {
                    ForEach(ViewingStatus.allCases) { status in
                        Label {
                            HStack {
                                Text(status.titleKey)
                                Spacer()
                                Text(statusCount(status), format: .number)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        } icon: {
                            Image(systemName: status.systemImage)
                        }
                        .tag(LibraryFilter.status(status))
                    }
                }
            }
            .listStyle(.sidebar)

            Divider()

            SidebarSettingsLink()
                .padding(8)
        }
        .navigationTitle("My Library")
    }

    @ViewBuilder
    private var content: some View {
        if selection == .tierList {
            TierListView(movies: movies) { movie in
                showDetails(for: movie)
            }
        } else if filteredMovies.isEmpty {
            ContentUnavailableView {
                Label(emptyTitle, systemImage: emptySystemImage)
            } description: {
                Text(emptyDescription)
            } actions: {
                Button("Add Title") {
                    presentAddMovie()
                }
                .buttonStyle(.borderedProminent)
            }
        } else {
            ScrollView {
                LazyVGrid(columns: grid, alignment: .leading, spacing: 32) {
                    ForEach(filteredMovies) { movie in
                        MovieCardView(movie: movie) {
                            showDetails(for: movie)
                        }
                    }
                }
                .padding(24)
            }
        }
    }

    private var filteredMovies: [Movie] {
        switch selection ?? .all {
        case .all:
            return movies
        case .movies:
            return movies.filter { $0.mediaKind == .movie }
        case .tierList:
            return movies
        case .series:
            return movies.filter { $0.mediaKind == .series }
        case .favorites:
            return movies.filter(\.isFavorite)
        case .status(let status):
            return movies.filter { $0.status == status }
        }
    }

    private func movie(withID id: UUID) -> Movie? {
        movies.first { $0.id == id }
    }

    private var selectionTitle: String {
        switch selection ?? .all {
        case .all:
            AppLocalization.string("All Titles", locale: locale)
        case .movies:
            AppLocalization.string("Movies", locale: locale)
        case .series:
            AppLocalization.string("Series", locale: locale)
        case .favorites:
            AppLocalization.string("Favorite", locale: locale)
        case .tierList:
            AppLocalization.string("Tier List", locale: locale)
        case .status(let status):
            status.localizedTitle(locale: locale)
        }
    }

    private var emptyTitle: LocalizedStringKey {
        selection == .all ? "Your Library Is Empty" : "No Titles Here"
    }

    private var emptyDescription: LocalizedStringKey {
        selection == .all
            ? "Add your first movie or series to start a personal collection."
            : "Titles matching this filter will appear here."
    }

    private var emptySystemImage: String {
        selection?.systemImage ?? "film.stack"
    }

    private var startupErrorBinding: Binding<Bool> {
        Binding(
            get: { startupError != nil },
            set: { if !$0 { startupError = nil } }
        )
    }

    private func statusCount(_ status: ViewingStatus) -> Int {
        movies.lazy.filter { $0.status == status }.count
    }

    private var favoriteCount: Int {
        movies.lazy.filter(\.isFavorite).count
    }

    private var movieCount: Int {
        movies.lazy.filter { $0.mediaKind == .movie }.count
    }

    private var seriesCount: Int {
        movies.lazy.filter { $0.mediaKind == .series }.count
    }

    private func sidebarLabel(_ title: LocalizedStringKey, count: Int) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(count, format: .number)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
    }

    private func presentAddMovie() {
        showsAddEditor = true
    }

    private func showDetails(for movie: Movie) {
        navigationPath = [movie.id]
    }
}

private struct SidebarSettingsLink: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        SettingsLink {
            Label("Settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 10)
                .frame(height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            Color.primary.opacity(isHovering ? 0.09 : 0.045),
            in: RoundedRectangle(cornerRadius: 8, style: .continuous)
        )
        .shadow(
            color: .black.opacity(isHovering ? 0.13 : 0.06),
            radius: isHovering ? 5 : 2,
            y: isHovering ? 3 : 1
        )
        .scaleEffect(isHovering && !reduceMotion ? 1.015 : 1)
        .animation(
            reduceMotion ? nil : .easeOut(duration: 0.16),
            value: isHovering
        )
        .onHover { isHovering = $0 }
    }
}
