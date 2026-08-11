import SwiftUI

struct StarRating: View {
    @Binding var rating: Int?
    var isEnabled = true
    var showsClearButton = true

    var body: some View {
        HStack(spacing: 2) {
            ForEach(1...5, id: \.self) { value in
                Button {
                    rating = value
                } label: {
                    Image(systemName: value <= (rating ?? 0) ? "star.fill" : "star")
                        .foregroundStyle(value <= (rating ?? 0) ? .yellow : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
                .disabled(!isEnabled)
                .accessibilityLabel(Text("\(value) stars"))
                .accessibilityAddTraits(rating == value ? .isSelected : [])
            }

            if showsClearButton, rating != nil {
                Button {
                    rating = nil
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.tertiary)
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
