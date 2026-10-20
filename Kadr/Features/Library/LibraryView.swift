import SwiftData
import SwiftUI

struct LibraryView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @AppStorage("appLanguage") private var appLanguageRawValue = AppLanguage.system.rawValue
    @Query(sort: \Movie.updatedAt, order: .reverse) private var movies: [Movie]

    @State private var selection: LibraryFilter? = .all
    @State private var columnVisibility: NavigationSplitViewVisibility = .all
    @State private var sidebarToggle = SidebarToggleAction()
    @State private var selectedMovie: Movie?
    @State private var showsAddEditor = false
    @State private var startupError: String?
    @State private var sidebarReflections: [SidebarReflection] = []

    private let grid = [
        GridItem(.adaptive(minimum: 180, maximum: 240), spacing: 24, alignment: .top)
    ]

    init(initialSelection: LibraryFilter = .all) {
        _selection = State(initialValue: initialSelection)
    }

    private var showsTierReflections: Bool {
        selection == .tierList && !movies.isEmpty && !reduceTransparency
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            sidebar
                .frame(minWidth: 220, idealWidth: 220, maxWidth: 280)
                .navigationSplitViewColumnWidth(min: 220, ideal: 220, max: 280)
                .toolbar(removing: .sidebarToggle)
        } detail: {
            VStack(alignment: .leading, spacing: 0) {
                if selection != .geography && selection != .tierList {
                    HStack(alignment: .firstTextBaseline) {
                        Text(selectionTitle).educaScreenTitle()
                        Spacer(minLength: 16)
                        Text("\(filteredMovies.count) titles")
                            .font(EducaType.caption)
                            .foregroundStyle(EducaColor.secondaryText)
                            .monospacedDigit()
                    }
                    .padding(.horizontal, EducaSpace.page)
                    .padding(.top, EducaSpace.panel)
                    .padding(.bottom, EducaSpace.sm)
                }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
                .toolbar(removing: .sidebarToggle)
                .background { EducaCanvas() }
                .navigationTitle(selectionTitle)
                .background(WindowTitleUpdater(title: selectionTitle))
                .background(SidebarToggleAnchor(action: sidebarToggle))
                .toolbar {
                    ToolbarItem(placement: .navigation) {
                        Button {
                            if reduceMotion || !sidebarToggle.toggle() {
                                columnVisibility = columnVisibility == .detailOnly ? .all : .detailOnly
                            }
                        } label: {
                            Image(systemName: "sidebar.left")
                                .frame(width: 40, height: 40)
                        }
                        .buttonStyle(EducaButtonStyle(kind: .icon))
                        .help("Toggle Sidebar")
                        .accessibilityLabel("Toggle Sidebar")
                    }
                    .sharedBackgroundVisibility(.hidden)

                    ToolbarItem(placement: .primaryAction) {
                        if selection != .geography {
                            Button {
                                presentAddMovie()
                            } label: {
                                Label("Add Title", systemImage: "plus")
                            }
                            .buttonStyle(EducaButtonStyle(kind: .primary))
                            .keyboardShortcut("n", modifiers: .command)
                            .help("Add Title")
                        }
                    }
                    .sharedBackgroundVisibility(.hidden)
                }
        }
        .navigationSplitViewStyle(.balanced)
        .coordinateSpace(name: SidebarReflection.coordinateSpace)
        .onPreferenceChange(SidebarReflectionPreferenceKey.self) { sidebarReflections = $0 }
        .toolbar(removing: .sidebarToggle)
        .toolbarBackground(.hidden, for: .windowToolbar)
        .sheet(item: $selectedMovie) { movie in
            MovieDetailView(movie: movie) {
                selectedMovie = nil
            }
            .environment(\.locale, locale)
            .educaRoot()
        }
        .sheet(isPresented: $showsAddEditor) {
            MovieEditorView()
                .environment(\.locale, locale)
                .educaRoot()
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
        .onChange(of: movies.map(\.id)) { _, movieIDs in
            if let selectedMovie, !movieIDs.contains(selectedMovie.id) {
                self.selectedMovie = nil
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

                Label("Viewing Map", systemImage: "globe.europe.africa")
                    .tag(LibraryFilter.geography)

                Section("Status") {
                    ForEach(ViewingStatus.allCases) { status in
                        Label {
                            HStack {
                                Text(status.titleKey)
                                Spacer()
                                Text(statusCount(status), format: .number)
                                    .foregroundStyle(EducaColor.secondaryText)
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
            .scrollContentBackground(.hidden)
            .font(EducaType.control)
            .symbolRenderingMode(.monochrome)

            EducaDivider()

            SidebarSettingsLink()
                .padding(8)
        }
        .background {
            EducaSidebarSurface(reduceTransparency: reduceTransparency, reflections: showsTierReflections ? sidebarReflections : [])
                .ignoresSafeArea(.container)
        }
        .navigationTitle("My Library")
    }

    @ViewBuilder
    private var content: some View {
        if selection == .geography {
            GeographyView(openMovie: { selectedMovie = $0 })
        } else if selection == .tierList {
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
                .buttonStyle(EducaButtonStyle(kind: .primary))
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
                .padding(EducaSpace.page)
            }
        }
    }

    private var filteredMovies: [Movie] {
        switch selection ?? .all {
        case .all:
            return movies
        case .movies:
            return movies.filter { $0.mediaKind == .movie }
        case .tierList, .geography:
            return movies
        case .series:
            return movies.filter { $0.mediaKind == .series }
        case .favorites:
            return movies.filter(\.isFavorite)
        case .status(let status):
            return movies.filter { $0.status == status }
        }
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
        case .geography:
            AppLocalization.string("Viewing Map", locale: locale)
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
                .foregroundStyle(EducaColor.secondaryText)
                .monospacedDigit()
        }
    }

    private func presentAddMovie() {
        showsAddEditor = true
    }

    private func showDetails(for movie: Movie) {
        selectedMovie = movie
    }
}

private struct SidebarSettingsLink: View {
    var body: some View {
        SettingsLink {
            Label("Settings", systemImage: "gearshape")
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(EducaButtonStyle())
    }
}
