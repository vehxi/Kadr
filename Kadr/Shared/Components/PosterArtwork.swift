import AppKit
import SwiftUI

extension EnvironmentValues {
    @Entry var coverStore: CoverStore = .shared
    @Entry var coverThumbnailLoader: CoverThumbnailLoader = .shared
}

struct PosterArtwork: View {
    let title: String
    let filename: String?
    var mediaKind: MediaKind = .movie
    var cornerRadius: CGFloat = 10

    @Environment(\.locale) private var locale
    @Environment(\.displayScale) private var displayScale
    @Environment(\.coverStore) private var coverStore
    @Environment(\.coverThumbnailLoader) private var thumbnailLoader
    @State private var image: NSImage?
    @State private var loadedFilename: String?

    private struct LoadRequest: Hashable {
        let filename: String?
        let size: CoverThumbnailSize?
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(EducaColor.raised)

                if let image {
                    FillingPosterImage(image: image)
                        .frame(
                            width: geometry.size.width,
                            height: geometry.size.height
                        )
                        .clipped()
                        .accessibilityLabel(Text("Cover for \(title)"))
                } else {
                    placeholder(compact: geometry.size.width < 140)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(EducaColor.border)
            }
            .task(id: LoadRequest(filename: filename, size: CoverThumbnailSize.forView(geometry.size, scale: displayScale))) {
                await loadImage(size: CoverThumbnailSize.forView(geometry.size, scale: displayScale))
            }
            .onDisappear {
                image = nil
                loadedFilename = nil
            }
        }
    }

    private func placeholder(compact: Bool) -> some View {
        VStack(spacing: 12) {
            Image(systemName: mediaKind.systemImage)
                .font(.system(size: compact ? 24 : 32, weight: .light))
                .foregroundStyle(EducaColor.mutedText)
            if !compact {
                Text(title.isEmpty ? untitledLabel : title)
                    .font(EducaType.heading)
                    .multilineTextAlignment(.center)
                    .lineLimit(3)
                    .foregroundStyle(EducaColor.secondaryText)
                    .padding(.horizontal, EducaSpace.lg)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(Text("No cover. \(title)"))
    }

    private var untitledLabel: String {
        switch mediaKind {
        case .movie: AppLocalization.string("Untitled Movie", locale: locale)
        case .series: AppLocalization.string("Untitled Series", locale: locale)
        }
    }

    @MainActor
    private func loadImage(size: CoverThumbnailSize?) async {
        if loadedFilename != filename { image = nil }
        guard let filename, let size,
              let url = await coverStore.url(for: filename)
        else {
            image = nil
            return
        }
        let thumbnail = await thumbnailLoader.image(at: url, size: size)
        guard !Task.isCancelled else { return }
        image = thumbnail.map { NSImage(cgImage: $0, size: NSSize(width: $0.width, height: $0.height)) }
        loadedFilename = filename
    }
}

/// Fill the frame proportionally, cropping excess edges around the image's center.
struct FillingPosterImage: View {
    let image: NSImage

    var body: some View {
        GeometryReader { geometry in
            Image(nsImage: image)
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
        }
    }
}
