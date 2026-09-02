import SwiftUI

struct StarRating: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Binding var rating: Int?
    var isEnabled = true
    var showsClearButton = true

    @State private var hoveredRating: Int?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                let isHovered = isEnabled && hoveredRating == value
                let isFilled = value <= (hoveredRating ?? rating ?? 0)

                Button {
                    rating = value
                } label: {
                    ZStack {
                        Image(systemName: "star")
                            .foregroundStyle(.secondary)
                            .opacity(isFilled ? 0 : 1)

                        Image(systemName: "star.fill")
                            .foregroundStyle(.yellow)
                            .opacity(isFilled ? 1 : 0)

                        Image(systemName: "star")
                            .foregroundStyle(.primary.opacity(0.70))
                            .opacity(isFilled ? 1 : 0)
                    }
                        .scaleEffect(isHovered ? 1.12 : 1)
                        .animation(
                            reduceMotion ? nil : .easeOut(duration: 0.16),
                            value: hoveredRating
                        )
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .disabled(!isEnabled)
                .onHover { isHovering in
                    if isHovering, isEnabled {
                        hoveredRating = value
                    } else if hoveredRating == value {
                        hoveredRating = nil
                    }
                }
                .accessibilityLabel(Text("\(value) stars"))
                .accessibilityAddTraits(rating == value ? .isSelected : [])
            }

            if showsClearButton, rating != nil {
                Button {
                    rating = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .disabled(!isEnabled)
                .accessibilityLabel("Clear Rating")
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Rating")
    }
}
