import CoreGraphics
import Dispatch
import Foundation
import ImageIO

struct CoverThumbnailSize: Hashable, Sendable {
    let width: Int
    let height: Int

    init(width: Int, height: Int) {
        self.width = max(1, width)
        self.height = max(1, height)
    }

    static func forView(_ size: CGSize, scale: CGFloat) -> Self? {
        guard size.width.isFinite, size.height.isFinite, scale.isFinite,
              size.width > 0, size.height > 0, scale > 0 else { return nil }
        // Buckets avoid decoding a new variant for each pixel while resizing a window.
        func bucket(_ points: CGFloat) -> Int {
            Int(ceil(min(points * scale, 16_384) / 32)) * 32
        }
        return Self(width: bucket(size.width), height: bucket(size.height))
    }
}

/// One serial, non-main executor bounds decoding concurrency and coalesces queued cache hits.
/// Originals are read-only. Cache storage is exclusively in RAM, with a strict decoded-byte budget.
actor CoverThumbnailLoader {
    static let shared = CoverThumbnailLoader()
    private let byteLimit: Int
    private nonisolated let memoryPressureSource: any DispatchSourceMemoryPressure
    private var entries: [Key: Entry] = [:]
    private var clock: UInt64 = 0
    private(set) var cachedBytes = 0
    private(set) var decodeCount = 0

    private struct Key: Hashable {
        let url: URL
        let size: CoverThumbnailSize
    }

    private struct Entry {
        let image: CGImage
        let cost: Int
        var access: UInt64
    }

    init(byteLimit: Int = 48 * 1_024 * 1_024) {
        self.byteLimit = max(0, byteLimit)
        let source = DispatchSource.makeMemoryPressureSource(eventMask: [.warning, .critical], queue: .global(qos: .utility))
        self.memoryPressureSource = source
        source.setEventHandler { [weak self] in
            Task { await self?.removeAll() }
        }
        source.resume()
    }

    deinit { memoryPressureSource.cancel() }

    func image(at url: URL, size: CoverThumbnailSize) -> CGImage? {
        guard !Task.isCancelled else { return nil }
        let key = Key(url: url.standardizedFileURL, size: size)
        clock &+= 1
        if var entry = entries[key] {
            entry.access = clock
            entries[key] = entry
            return entry.image
        }

        let image = autoreleasepool { decode(url: key.url, size: size) }
        guard !Task.isCancelled, let image else { return nil }
        decodeCount += 1
        let cost = image.bytesPerRow * image.height
        // An oversized result can be displayed without displacing the entire cache.
        if cost <= byteLimit {
            while cachedBytes > byteLimit - cost,
                  let oldest = entries.min(by: { $0.value.access < $1.value.access }) {
                entries.removeValue(forKey: oldest.key)
                cachedBytes -= oldest.value.cost
            }
            entries[key] = Entry(image: image, cost: cost, access: clock)
            cachedBytes += cost
        }
        return image
    }

    func removeAll() {
        entries.removeAll()
        cachedBytes = 0
    }

    private func decode(url: URL, size: CoverThumbnailSize) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL,
                [kCGImageSourceShouldCache: false] as CFDictionary),
              let properties = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let rawWidth = properties[kCGImagePropertyPixelWidth] as? NSNumber,
              let rawHeight = properties[kCGImagePropertyPixelHeight] as? NSNumber else { return nil }

        let orientation = (properties[kCGImagePropertyOrientation] as? NSNumber)?.intValue ?? 1
        let rotated = (5...8).contains(orientation)
        let width = rotated ? rawHeight.doubleValue : rawWidth.doubleValue
        let height = rotated ? rawWidth.doubleValue : rawHeight.doubleValue
        guard width > 0, height > 0 else { return nil }
        // Aspect-fill requires enough pixels along BOTH axes, including landscape covers.
        let ratio = min(1, max(Double(size.width) / width, Double(size.height) / height))
        let maximumDimension = max(1, Int(ceil(max(width, height) * ratio)))
        return CGImageSourceCreateThumbnailAtIndex(source, 0, [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumDimension,
            kCGImageSourceShouldCacheImmediately: true
        ] as CFDictionary)
    }
}
