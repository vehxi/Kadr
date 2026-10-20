import AppKit
import SwiftUI

struct PosterArtwork: View {
    let title: String
    let filename: String?
    var mediaKind: MediaKind = .movie
    var cornerRadius: CGFloat = 10

    @Environment(\.locale) private var locale
    @State private var image: NSImage?

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
        }
        .task(id: filename) {
            await loadImage()
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
    private func loadImage() async {
        guard let filename,
              let url = await CoverStore.shared.url(for: filename)
        else {
            image = nil
            return
        }
        image = NSImage(contentsOf: url)
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
