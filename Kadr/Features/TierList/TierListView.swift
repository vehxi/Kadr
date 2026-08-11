import SwiftData
import SwiftUI

struct TierListView: View {
    let movies: [Movie]
    let openMovie: (Movie) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.modelContext) private var modelContext
    @State private var saveError: String?

    var body: some View {
        Group {
            if movies.isEmpty {
                ContentUnavailableView {
                    Label("Your Library Is Empty", systemImage: "square.grid.3x3.square")
                } description: {
                    Text("Add movies to your library before building a tier list.")
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        intro

                        ForEach(MovieTier.allCases) { tier in
                            tierLane(tier)
                        }

                        unrankedLane
                    }
                    .padding(24)
                }
            }
        }
        .alert("Could Not Save Tier List", isPresented: saveErrorBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(saveError ?? "")
        }
    }

    private var intro: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Build Your Ranking")
                    .font(.title2.weight(.semibold))
                Text("Drag every poster into the tier where it belongs.")
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(movies.count) movies")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
        }
        .padding(.bottom, 8)
    }

    private func tierLane(_ tier: MovieTier) -> some View {
        TierLane(
            title: tier.label,
            subtitle: "\(movies(in: tier).count)",
            color: tier.color,
            movies: movies(in: tier),
            openMovie: openMovie,
            move: move,
            onDrop: { move(movieID: $0, to: tier) }
        )
    }

    private var unrankedLane: some View {
        TierLane(
            title: "—",
            subtitle: String(localized: "Unranked"),
            color: .secondary,
            movies: unrankedMovies,
            openMovie: openMovie,
            move: move,
            onDrop: { move(movieID: $0, to: nil) }
        )
    }

    private var unrankedMovies: [Movie] {
        movies.filter { $0.tier == nil }
    }

    private func movies(in tier: MovieTier) -> [Movie] {
        movies.filter { $0.tier == tier }
    }

    private func move(_ movie: Movie, to tier: MovieTier?) {
        guard movie.tier != tier else { return }

        if reduceMotion {
            update(movie, tier: tier)
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                update(movie, tier: tier)
            }
        }
    }

    private func move(movieID: String, to tier: MovieTier?) -> Bool {
        guard
            let id = UUID(uuidString: movieID),
            let movie = movies.first(where: { $0.id == id })
        else {
            return false
        }

        move(movie, to: tier)
        return true
    }

    private func update(_ movie: Movie, tier: MovieTier?) {
        movie.tier = tier
        movie.updatedAt = .now

        do {
            try modelContext.save()
        } catch {
            saveError = error.localizedDescription
        }
    }

    private var saveErrorBinding: Binding<Bool> {
        Binding(
            get: { saveError != nil },
            set: { if !$0 { saveError = nil } }
        )
    }
}

private struct TierLane: View {
    let title: String
    let subtitle: String
    let color: Color
    let movies: [Movie]
    let openMovie: (Movie) -> Void
    let move: (Movie, MovieTier?) -> Void
    let onDrop: (String) -> Bool

    @State private var isDropTarget = false

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 6) {
                Text(title)
                    .font(.system(size: 34, weight: .black, design: .rounded))
                    .foregroundStyle(title == "—" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white))

                Text(subtitle)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(title == "—" ? AnyShapeStyle(.secondary) : AnyShapeStyle(.white.opacity(0.82)))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(width: 88)
            .frame(maxHeight: .infinity)
            .background(color.opacity(title == "—" ? 0.10 : 0.84))

            ScrollView(.horizontal) {
                LazyHStack(alignment: .top, spacing: 14) {
                    if movies.isEmpty {
                        Label("Drop movies here", systemImage: "arrow.down.to.line")
                            .font(.subheadline)
                            .foregroundStyle(.tertiary)
                            .frame(minWidth: 160, minHeight: 176)
                    } else {
                        ForEach(movies) { movie in
                            TierMovieCardView(
                                movie: movie,
                                action: { openMovie(movie) },
                                move: { move(movie, $0) }
                            )
                        }
                    }
                }
                .padding(16)
            }
            .scrollIndicators(.hidden)
        }
        .frame(minHeight: 196)
        .background(isDropTarget ? color.opacity(0.13) : Color.primary.opacity(0.035))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
        .shadow(color: .black.opacity(0.08), radius: 3, y: 1)
        .dropDestination(for: String.self) { items, _ in
            guard let movieID = items.first else { return false }
            return onDrop(movieID)
        } isTargeted: {
            isDropTarget = $0
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("\(title) tier, \(movies.count) movies"))
    }
}
