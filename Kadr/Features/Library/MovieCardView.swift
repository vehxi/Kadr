import SwiftUI

struct MovieCardView: View {
    let movie: Movie
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isHovering = false

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                PosterArtwork(
                    title: movie.title,
                    filename: movie.coverFilename,
                    mediaKind: movie.mediaKind
                )
                    .aspectRatio(2 / 3, contentMode: .fit)
                    .shadow(
                        color: .black.opacity(isHovering ? 0.20 : 0.12),
                        radius: isHovering ? 9 : 4,
                        y: isHovering ? 5 : 2
                    )
                    .overlay(alignment: .bottomTrailing) {
                        Image(systemName: "arrow.up.right")
                            .font(.caption.weight(.semibold))
                            .padding(8)
                            .background(.regularMaterial, in: Circle())
                            .padding(8)
                            .opacity(isHovering ? 1 : 0)
                            .accessibilityHidden(true)
                    }
                    .overlay(alignment: .topTrailing) {
                        if movie.isFavorite {
                            Image(systemName: "heart.fill")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.red)
                                .padding(8)
                                .background(.regularMaterial, in: Circle())
                                .padding(8)
                                .accessibilityHidden(true)
                        }
                    }

                Text(movie.title)
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    if let releasePeriodText = movie.releasePeriodText {
                        Text(releasePeriodText)
                    }
                    if movie.mediaKind == .series {
                        Label(
                            "\(movie.watchedEpisodeCount)/\(movie.episodeCount)",
                            systemImage: "checkmark.circle"
                        )
                        .labelStyle(.titleAndIcon)
                    }
                    if movie.rating != nil {
                        Label("\(movie.rating ?? 0)", systemImage: "star.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.secondary)
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(height: 16)
            }
            .contentShape(Rectangle())
            .scaleEffect(isHovering && !reduceMotion ? 1.015 : 1)
            .animation(
                reduceMotion ? nil : .easeOut(duration: 0.16),
                value: isHovering
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovering = $0 }
        .accessibilityLabel(accessibilityDescription)
    }

    private var accessibilityDescription: Text {
        var description = movie.title
        if let releasePeriodText = movie.releasePeriodText {
            description += ", \(releasePeriodText)"
        }
        if movie.mediaKind == .series {
            description += ", \(String(localized: "Series")), \(movie.watchedEpisodeCount) of \(movie.episodeCount) episodes watched"
        }
        if movie.isFavorite {
            description += ", \(String(localized: "Favorite"))"
        }
        return Text(description)
    }
}
