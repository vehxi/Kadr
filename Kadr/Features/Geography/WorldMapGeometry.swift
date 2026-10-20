import Foundation
import SwiftUI

struct WorldMapCountry: Decodable, Identifiable {
    let id: String
    let name: String
    let rings: [[[Double]]]

    func localizedName(locale: Locale) -> String {
        locale.localizedString(forRegionCode: id) ?? name
    }

    var path: Path {
        Path { path in
            for ring in rings {
                guard let first = ring.first, first.count == 2 else { continue }
                path.move(to: CGPoint(x: first[0], y: first[1]))
                for point in ring.dropFirst() where point.count == 2 {
                    path.addLine(to: CGPoint(x: point[0], y: point[1]))
                }
                path.closeSubpath()
            }
        }
    }
}

struct WorldMapOutline: Identifiable {
    let country: WorldMapCountry
    let path: Path
    let bounds: CGRect
    var id: String { country.id }
}

struct WorldMapGeometry {
    let outlines: [WorldMapOutline]

    static func load() throws -> Self {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle.main
        #endif
        guard let url = bundle.url(forResource: "world-countries", withExtension: "json") else {
            throw CocoaError(.fileNoSuchFile)
        }
        return try decode(Data(contentsOf: url))
    }

    static func decode(_ data: Data) throws -> Self {
        struct Archive: Decodable { let countries: [WorldMapCountry] }
        let archive = try JSONDecoder().decode(Archive.self, from: data)
        return Self(outlines: archive.countries.map { country in
            let path = country.path
            return WorldMapOutline(country: country, path: path, bounds: path.boundingRect)
        })
    }

    func country(at point: CGPoint) -> WorldMapCountry? {
        outlines.first { $0.bounds.contains(point) && $0.path.contains(point, eoFill: true) }?.country
    }
}

struct WorldMapViewport {
    let size: CGSize
    var zoom: CGFloat = 1
    var offset: CGSize = .zero

    var mapRect: CGRect {
        let width = max(1, min(size.width - 32, (size.height - 32) * 2.2))
        let height = width / 2.2
        return CGRect(x: (size.width - width) / 2, y: (size.height - height) / 2, width: width, height: height)
    }

    var transform: CGAffineTransform {
        CGAffineTransform(
            a: mapRect.width * zoom, b: 0, c: 0, d: mapRect.height * zoom,
            tx: mapRect.midX - mapRect.width * zoom / 2 + offset.width,
            ty: mapRect.midY - mapRect.height * zoom / 2 + offset.height
        )
    }

    func mapPoint(at point: CGPoint) -> CGPoint {
        point.applying(transform.inverted())
    }

    func constrained(_ proposed: CGSize) -> CGSize {
        let xLimit = mapRect.width * (zoom - 1) / 2
        let yLimit = mapRect.height * (zoom - 1) / 2
        return CGSize(
            width: min(xLimit, max(-xLimit, proposed.width)),
            height: min(yLimit, max(-yLimit, proposed.height))
        )
    }
}
