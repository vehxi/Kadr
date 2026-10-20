import SwiftUI

struct WorldMapCanvas: View {
    let geometry: WorldMapGeometry
    let metric: GeographyMetric
    let statistics: GeographyStatistics
    @Binding var selectedCode: String

    @Environment(\.locale) private var locale
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var hoveredCountry: WorldMapCountry?
    @State private var zoom: CGFloat = 1
    @State private var offset: CGSize = .zero
    @GestureState private var drag: CGSize = .zero
    @GestureState private var magnification: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            let effectiveZoom = min(8, max(1, zoom * magnification))
            let base = WorldMapViewport(size: proxy.size, zoom: effectiveZoom)
            let viewport = WorldMapViewport(
                size: proxy.size,
                zoom: effectiveZoom,
                offset: base.constrained(CGSize(width: offset.width + drag.width, height: offset.height + drag.height))
            )

            Canvas { context, _ in
                for outline in geometry.outlines {
                    let path = outline.path.applying(viewport.transform)
                    context.fill(path, with: .color(color(for: outline.id)), style: FillStyle(eoFill: true))
                    context.stroke(path, with: .color(EducaColor.text.opacity(0.16)), lineWidth: 0.55)
                }

                // Highlight last so adjacent polygons cannot cover the focus outline.
                for outline in geometry.outlines where outline.id == selectedCode || outline.id == hoveredCountry?.id {
                    let path = outline.path.applying(viewport.transform)
                    if outline.id == selectedCode {
                        context.stroke(path, with: .color(EducaColor.panel), lineWidth: 4)
                    }
                    context.stroke(
                        path,
                        with: .color(EducaColor.text.opacity(outline.id == selectedCode ? 1 : 0.7)),
                        lineWidth: outline.id == selectedCode ? 2 : 1.2
                    )
                }
            }
            .accessibilityHidden(true)
            .contentShape(Rectangle())
            .onContinuousHover { phase in
                switch phase {
                case .active(let location):
                    hoveredCountry = geometry.country(at: viewport.mapPoint(at: location))
                case .ended:
                    hoveredCountry = nil
                }
            }
            .gesture(
                DragGesture(minimumDistance: 4)
                    .updating($drag) { value, state, _ in state = value.translation }
                    .onEnded { value in
                        offset = base.constrained(CGSize(
                            width: offset.width + value.translation.width,
                            height: offset.height + value.translation.height
                        ))
                        hoveredCountry = nil
                    }
            )
            .simultaneousGesture(
                SpatialTapGesture().onEnded { value in
                    if let country = geometry.country(at: viewport.mapPoint(at: value.location)) {
                        selectedCode = country.id
                    }
                }
            )
            .simultaneousGesture(
                MagnifyGesture()
                    .updating($magnification) { value, state, _ in state = value.magnification }
                    .onEnded { value in
                        zoom = min(8, max(1, zoom * value.magnification))
                        offset = WorldMapViewport(size: proxy.size, zoom: zoom).constrained(offset)
                        hoveredCountry = nil
                    }
            )
            .onChange(of: proxy.size) {
                offset = WorldMapViewport(size: proxy.size, zoom: zoom).constrained(offset)
                hoveredCountry = nil
            }
            .overlay(alignment: .topLeading) { hoverLabel }
            .overlay(alignment: .bottomLeading) {
                Text("Drag to move · Pinch to zoom")
                    .font(.caption2)
                    .foregroundStyle(EducaColor.secondaryText)
                    .padding(14)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottomTrailing) { controls(size: proxy.size) }
        }
        .clipShape(RoundedRectangle(cornerRadius: EducaRadius.panel, style: .continuous))
        .educaPanel(padding: 0)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("World viewing map")
    }

    @ViewBuilder
    private var hoverLabel: some View {
        if let country = hoveredCountry {
            let statistics = statistics.statistics(for: country.id)
            VStack(alignment: .leading, spacing: 3) {
                Text(country.localizedName(locale: locale)).font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text("\(statistics.count) movies")
                    if let average = statistics.average {
                        Label(
                            average.formatted(.number.precision(.fractionLength(1)).locale(locale)),
                            systemImage: "star.fill"
                        )
                        .foregroundStyle(EducaColor.secondaryText)
                    }
                }
                .font(.caption)
                .foregroundStyle(EducaColor.secondaryText)
            }
            .padding(10)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 9))
            .padding(12)
            .allowsHitTesting(false)
        }
    }

    private func controls(size: CGSize) -> some View {
        HStack(spacing: 0) {
            Button {
                changeViewport {
                    zoom = 1
                    offset = .zero
                }
            } label: {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 40, height: 40)
            }
            .accessibilityLabel("Reset Map")
            .help("Reset Map")

            Rectangle().fill(EducaColor.border).frame(width: 1, height: 18)

            Button {
                setZoom(zoom / 1.5, size: size)
            } label: {
                Image(systemName: "minus").frame(width: 40, height: 40)
            }
            .disabled(zoom <= 1)
            .accessibilityLabel("Zoom Out")
            .help("Zoom Out")

            Button {
                setZoom(zoom * 1.5, size: size)
            } label: {
                Image(systemName: "plus").frame(width: 40, height: 40)
            }
            .disabled(zoom >= 8)
            .accessibilityLabel("Zoom In")
            .help("Zoom In")
        }
        .buttonStyle(EducaButtonStyle(kind: .icon))
        .background(EducaColor.panel, in: RoundedRectangle(cornerRadius: EducaRadius.button))
        .padding(12)
    }

    private func color(for countryCode: String) -> Color {
        let countryStatistics = statistics.statistics(for: countryCode)
        guard let intensity = metric.intensity(
            count: countryStatistics.count,
            average: countryStatistics.average,
            maximumCount: statistics.maximumCount
        ) else {
            return EducaColor.text.opacity(0.085)
        }
        return EducaColor.text.opacity(0.18 + intensity * 0.82)
    }

    private func setZoom(_ value: CGFloat, size: CGSize) {
        changeViewport {
            zoom = min(8, max(1, value))
            offset = WorldMapViewport(size: size, zoom: zoom).constrained(offset)
        }
    }

    private func changeViewport(_ change: () -> Void) {
        hoveredCountry = nil
        if reduceMotion {
            change()
        } else {
            withAnimation(.easeOut(duration: 0.18), change)
        }
    }
}
