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
                            .foregroundStyle(EducaColor.secondaryText)
                            .opacity(isFilled ? 0 : 1)

                        Image(systemName: "star.fill")
                            .foregroundStyle(EducaColor.text)
                            .opacity(isFilled ? 1 : 0)

                        Image(systemName: "star")
                            .foregroundStyle(EducaColor.text)
                            .opacity(isFilled ? 1 : 0)
                    }
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                        .scaleEffect(isHovered && !reduceMotion ? 1.08 : 1)
                        .animation(
                            reduceMotion ? nil : EducaMotion.feedback,
                            value: hoveredRating
                        )
                }
                .buttonStyle(EducaPosterButtonStyle())
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
                        .foregroundStyle(EducaColor.secondaryText)
                        .frame(width: 40, height: 40)
                        .contentShape(Rectangle())
                }
                .buttonStyle(EducaPosterButtonStyle())
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
