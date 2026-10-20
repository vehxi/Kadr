import SwiftUI
import SwiftData

struct GeographyView: View {
    private let loadGeometry: () throws -> WorldMapGeometry
    private let openMovie: (Movie) -> Void
    @Query(sort: \Movie.title) private var movies: [Movie]
    @Environment(\.locale) private var locale
    @State private var geometry: WorldMapGeometry?
    @State private var loadingFailed = false
    @State private var metric = GeographyMetric.watches
    @State private var selectedCountryCode = "JP"

    init(openMovie: @escaping (Movie) -> Void = { _ in }, loadGeometry: @escaping () throws -> WorldMapGeometry = WorldMapGeometry.load) {
        self.openMovie = openMovie
        self.loadGeometry = loadGeometry
    }

    var body: some View {
        Group {
            if let geometry {
                page(geometry)
            } else if loadingFailed {
                ContentUnavailableView {
                    Label("Map Unavailable", systemImage: "globe.europe.africa")
                } description: {
                    Text("The world map could not be loaded.")
                } actions: {
                    Button("Try Again", action: loadMap)
                }
            } else {
                EducaLoadingState("Loading Map…")
            }
        }
        .task { loadMap() }
    }

    private func page(_ geometry: WorldMapGeometry) -> some View {
        let statistics = GeographyStatistics(movies: movies)
        return GeometryReader { proxy in
            let wide = proxy.size.width >= 760
            let mapHeight = max(360, min(520, proxy.size.height - 210))
            ScrollView {
                VStack(alignment: .leading, spacing: EducaSpace.panel) {
                    header
                    summary(statistics)

                    if wide {
                        HStack(alignment: .top, spacing: 16) {
                            map(geometry, height: mapHeight, statistics: statistics)
                            countryPanel(geometry, statistics: statistics)
                                .frame(width: 248, height: mapHeight + 42)
                        }
                    } else {
                        map(geometry, height: mapHeight, statistics: statistics)
                        countryPanel(geometry, statistics: statistics)
                            .frame(height: 330)
                    }

                    Label("Only watched titles contribute to the map. Coproductions count in each country.", systemImage: "info.circle")
                    .font(.caption)
                    .foregroundStyle(EducaColor.secondaryText)
                    .fixedSize(horizontal: false, vertical: true)

                    if !statistics.missingCountries.isEmpty {
                        DisclosureGroup {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Open a title and edit its production countries to add it to the map.")
                                    .font(.caption).foregroundStyle(EducaColor.secondaryText)
                                ForEach(statistics.missingCountries) { movie in
                                    Button { openMovie(movie) } label: {
                                        Label(movie.title, systemImage: movie.mediaKind.systemImage)
                                            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                    }
                                    .buttonStyle(EducaButtonStyle())
                                }
                            }
                            .padding(.top, 12)
                        } label: {
                            Text("\(statistics.missingCountries.count) watched titles without countries")
                                .font(.subheadline.weight(.medium))
                        }
                        .educaPanel()
                    }
                }
                .padding(EducaSpace.page)
            }
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 5) {
                Text("A World of Cinema")
                    .educaScreenTitle()
                Text("Explore the countries behind the films.")
                    .foregroundStyle(EducaColor.secondaryText)
            }
            Spacer(minLength: 0)
        }
    }

    private func summary(_ statistics: GeographyStatistics) -> some View {
        HStack(spacing: 24) {
            summaryItem(value: statistics.watched.count.formatted(.number.locale(locale)), title: "Watched titles")
            summaryItem(value: statistics.byCountry.count.formatted(.number.locale(locale)), title: "Countries explored")
            summaryItem(value: averageText(statistics.average), title: "Average rating")
            Spacer(minLength: 0)
        }
        .educaPanel()
    }

    private func summaryItem(value: String, title: LocalizedStringKey) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(value)
                .font(.system(size: 28, weight: .semibold))
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(EducaColor.secondaryText)
        }
    }

    private func map(_ geometry: WorldMapGeometry, height: CGFloat, statistics: GeographyStatistics) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                metricPicker.pickerStyle(.segmented).fixedSize()
                metricPicker.pickerStyle(.menu)
            }
            .frame(height: 32)

            WorldMapCanvas(
                geometry: geometry,
                metric: metric,
                statistics: statistics,
                selectedCode: $selectedCountryCode
            )
            .frame(height: height - 44)

            HStack(spacing: 7) {
                Text("No data")
                Circle().fill(EducaColor.text.opacity(0.085)).frame(width: 7, height: 7)
                Spacer(minLength: 8)
                Text(metric == .watches ? (statistics.maximumCount == 0 ? "0" : "1") : "1 ★")
                HStack(spacing: 3) {
                    ForEach(0..<5) { step in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(EducaColor.text.opacity(legendOpacity(step: step, maximumCount: statistics.maximumCount)))
                            .frame(width: 20, height: 7)
                    }
                }
                Text(metric == .watches ? String(statistics.maximumCount) : "5 ★")
            }
            .font(.caption2)
            .foregroundStyle(EducaColor.secondaryText)
        }
        .frame(maxWidth: .infinity)
    }

    private var metricPicker: some View {
        Picker("Map Mode", selection: $metric) {
            ForEach(GeographyMetric.allCases) { metric in
                Text(LocalizedStringKey(metric.title)).tag(metric)
            }
        }
        .labelsHidden()
    }

    private func countryPanel(_ geometry: WorldMapGeometry, statistics: GeographyStatistics) -> some View {
        let countries = ProductionCountries.sortedCodes(locale: locale)
        let statistics = statistics.statistics(for: selectedCountryCode)

        return VStack(alignment: .leading, spacing: 16) {
            Picker("Country", selection: $selectedCountryCode) {
                ForEach(countries, id: \.self) { code in
                    Text(ProductionCountries.name(for: code, locale: locale)).tag(code)
                }
            }
            .labelsHidden()
            .accessibilityLabel("Country")
            .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)

            Text(ProductionCountries.name(for: selectedCountryCode, locale: locale))
                .font(EducaType.title)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 24) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(statistics.count, format: .number).font(.title3.weight(.semibold))
                    Text("Watched titles").font(.caption).foregroundStyle(EducaColor.secondaryText)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Label(averageText(statistics.average), systemImage: "star.fill")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(EducaColor.text)
                    Text("Average rating").font(.caption).foregroundStyle(EducaColor.secondaryText)
                }
            }
            .monospacedDigit()

            EducaDivider()

            if statistics.count > 0 && !geometry.outlines.contains(where: { $0.id == selectedCountryCode }) {
                Text("This country's outline is not available at this map scale.")
                    .font(.caption).foregroundStyle(EducaColor.secondaryText)
            }

            if statistics.films.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Image(systemName: "film")
                        .font(.title2)
                        .foregroundStyle(EducaColor.mutedText)
                    Text("No watched titles from this country yet.")
                        .font(.subheadline)
                        .foregroundStyle(EducaColor.secondaryText)
                }
                Spacer(minLength: 0)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        ForEach(statistics.films) { film in
                            Button { openMovie(film) } label: {
                                HStack(alignment: .center, spacing: 10) {
                                    PosterArtwork(
                                        title: film.title,
                                        filename: film.coverFilename,
                                        mediaKind: film.mediaKind,
                                        cornerRadius: 4
                                    )
                                        .frame(width: 32, height: 48)
                                        .accessibilityHidden(true)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(film.title)
                                            .font(.subheadline.weight(.medium))
                                        HStack(spacing: 8) {
                                            if let period = film.releasePeriodText { Text(period) }
                                            if let rating = film.rating {
                                                Label(String(rating), systemImage: "star.fill")
                                                    .foregroundStyle(EducaColor.secondaryText)
                                            }
                                        }
                                        .font(.caption)
                                        .foregroundStyle(EducaColor.secondaryText)
                                    }
                                }
                                .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                                .padding(.vertical, 8)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(EducaButtonStyle())
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .educaPanel()
    }

    private func averageText(_ average: Double?) -> String {
        average?.formatted(.number.precision(.fractionLength(1)).locale(locale)) ?? "—"
    }

    private func legendOpacity(step: Int, maximumCount: Int) -> Double {
        let maximum = max(1, maximumCount)
        let count = 1 + Int((Double(maximum - 1) * Double(step) / 4).rounded())
        let intensity = metric.intensity(count: count, average: Double(step + 1), maximumCount: maximum) ?? 0
        return 0.18 + intensity * 0.82
    }

    private func loadMap() {
        loadingFailed = false
        do {
            geometry = try loadGeometry()
            let statistics = GeographyStatistics(movies: movies)
            if let first = statistics.byCountry.keys.sorted().first {
                selectedCountryCode = first
            }
        } catch {
            loadingFailed = true
        }
    }
}
