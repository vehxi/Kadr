import SwiftUI

struct TierMovieCardView: View {
    let movie: Movie
    let action: () -> Void
    let move: (MovieTier?) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 7) {
                PosterArtwork(title: movie.title, filename: movie.coverFilename)
                    .frame(width: 96, height: 144)
                    .shadow(
                        color: .black.opacity(isHovering ? 0.22 : 0.12),
                        radius: isHovering ? 8 : 3,
                        y: isHovering ? 5 : 2
                    )

                Text(movie.title)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .frame(width: 96, alignment: .leading)
            }
            .contentShape(Rectangle())
            .scaleEffect(isHovering && !reduceMotion ? 1.025 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.16),
                value: isHovering
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .draggable(movie.id.uuidString) {
            PosterArtwork(title: movie.title, filename: movie.coverFilename)
                .frame(width: 80, height: 120)
                .shadow(color: .black.opacity(0.24), radius: 10, y: 6)
        }
        .contextMenu {
            Section("Move to Tier") {
                ForEach(MovieTier.allCases) { tier in
                    Button {
                        move(tier)
                    } label: {
                        Label("\(tier.label) Tier", systemImage: movie.tier == tier ? "checkmark" : "square")
                    }
                }

                Button {
                    move(nil)
                } label: {
                    Label("Unranked", systemImage: movie.tier == nil ? "checkmark" : "tray")
                }
            }
        }
        .accessibilityLabel(Text(movie.title))
        .accessibilityHint(Text("Drag to move this movie to another tier."))
    }
}
