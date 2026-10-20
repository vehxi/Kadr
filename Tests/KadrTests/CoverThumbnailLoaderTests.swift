import CoreGraphics
import Foundation
import ImageIO
import Testing
import UniformTypeIdentifiers

#if SWIFT_PACKAGE
@testable import Kadr
#else
@testable import MyMovies
#endif

struct CoverThumbnailLoaderTests {
    @Test func viewSizesRespectRetinaAndResizeBuckets() {
        #expect(CoverThumbnailSize.forView(CGSize(width: 240, height: 360), scale: 2)
            == CoverThumbnailSize(width: 480, height: 736))
        #expect(CoverThumbnailSize.forView(CGSize(width: 32, height: 48), scale: 2)
            == CoverThumbnailSize(width: 64, height: 96))
        #expect(CoverThumbnailSize.forView(.zero, scale: 2) == nil)
        #expect(CoverThumbnailSize.forView(CGSize(width: CGFloat.infinity, height: 10), scale: 2) == nil)
        #expect(CoverThumbnailSize.forView(CGSize(width: 10, height: 10), scale: 0) == nil)
    }

    @Test func downsamplingKeepsOriginalFileAndAspectRatio() async throws {
        let fixture = try Fixture(width: 1000, height: 1500)
        defer { fixture.remove() }
        let original = try Data(contentsOf: fixture.url)
        let loader = CoverThumbnailLoader()
        let image = try #require(await loader.image(at: fixture.url, size: CoverThumbnailSize(width: 200, height: 300)))
        #expect(image.width == 200 && image.height == 300)
        #expect(try Data(contentsOf: fixture.url) == original)
        #expect(await loader.cachedBytes == image.bytesPerRow * image.height)
    }

    @Test func landscapeHasEnoughPixelsForAspectFill() async throws {
        let fixture = try Fixture(width: 1600, height: 800)
        defer { fixture.remove() }
        let image = try #require(await CoverThumbnailLoader().image(at: fixture.url, size: CoverThumbnailSize(width: 200, height: 300)))
        #expect(image.width == 600 && image.height == 300)
    }

    @Test func orientationIsAppliedBeforeCalculatingSize() async throws {
        let fixture = try Fixture(width: 1500, height: 1000, orientation: 6)
        defer { fixture.remove() }
        let image = try #require(await CoverThumbnailLoader().image(at: fixture.url, size: CoverThumbnailSize(width: 200, height: 300)))
        #expect(image.width == 200 && image.height == 300)
    }

    @Test func smallOriginalIsNotUpscaled() async throws {
        let fixture = try Fixture(width: 40, height: 60)
        defer { fixture.remove() }
        let image = try #require(await CoverThumbnailLoader().image(at: fixture.url, size: CoverThumbnailSize(width: 400, height: 600)))
        #expect(image.width == 40 && image.height == 60)
    }

    @Test func concurrentSameRequestsShareOneCachedDecode() async throws {
        let fixture = try Fixture(width: 1000, height: 1500)
        defer { fixture.remove() }
        let loader = CoverThumbnailLoader()
        let size = CoverThumbnailSize(width: 200, height: 300)
        await withTaskGroup(of: Bool.self) { group in
            for _ in 0..<20 {
                group.addTask { await loader.image(at: fixture.url, size: size) != nil }
            }
            for await loaded in group { #expect(loaded) }
        }
        #expect(await loader.decodeCount == 1)
        let image = try #require(await loader.image(at: fixture.url, size: size))
        #expect(await loader.cachedBytes == image.bytesPerRow * image.height)
        await loader.removeAll()
        #expect(await loader.cachedBytes == 0)
        _ = await loader.image(at: fixture.url, size: size)
        #expect(await loader.decodeCount == 2)
    }

    @Test func cacheHasStrictByteLimitAndEvictsLeastRecentImage() async throws {
        let fixture = try Fixture(width: 1000, height: 1500)
        defer { fixture.remove() }
        let size = CoverThumbnailSize(width: 200, height: 300)
        let reference = try #require(await CoverThumbnailLoader(byteLimit: 0).image(at: fixture.url, size: size))
        let cost = reference.bytesPerRow * reference.height
        let loader = CoverThumbnailLoader(byteLimit: cost * 2)
        let second = fixture.directory.appendingPathComponent("second.jpg")
        let third = fixture.directory.appendingPathComponent("third.jpg")
        try FileManager.default.copyItem(at: fixture.url, to: second)
        try FileManager.default.copyItem(at: fixture.url, to: third)
        _ = await loader.image(at: fixture.url, size: size)
        _ = await loader.image(at: second, size: size)
        _ = await loader.image(at: fixture.url, size: size) // Keep the first image most recent.
        _ = await loader.image(at: third, size: size)
        #expect(await loader.cachedBytes <= cost * 2)
        #expect(await loader.decodeCount == 3)
        _ = await loader.image(at: fixture.url, size: size)
        #expect(await loader.decodeCount == 3)
        _ = await loader.image(at: second, size: size)
        #expect(await loader.decodeCount == 4)
        #expect(await loader.cachedBytes <= cost * 2)
    }

    @Test func missingCorruptAndCancelledRequestsDoNotPopulateCache() async throws {
        let fixture = try Fixture(width: 40, height: 60)
        defer { fixture.remove() }
        let loader = CoverThumbnailLoader(byteLimit: 1)
        let size = CoverThumbnailSize(width: 40, height: 60)
        #expect(await loader.image(at: fixture.directory.appendingPathComponent("absent.jpg"), size: size) == nil)
        let corrupt = fixture.directory.appendingPathComponent("corrupt.jpg")
        try Data([0, 1, 2]).write(to: corrupt)
        #expect(await loader.image(at: corrupt, size: size) == nil)
        #expect(await loader.cachedBytes == 0)
        let cancelled = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return await loader.image(at: fixture.url, size: size)
        }
        #expect(await cancelled.value == nil)
        #expect(await loader.decodeCount == 0)
        #expect(await loader.image(at: fixture.url, size: size) != nil)
        #expect(await loader.cachedBytes == 0) // Oversized result is returned but never cached.
    }

    private struct Fixture {
        let directory: URL
        let url: URL

        init(width: Int, height: Int, orientation: Int = 1) throws {
            directory = FileManager.default.temporaryDirectory.appendingPathComponent("kadr-thumbnail-test-\(UUID())")
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            url = directory.appendingPathComponent("cover.jpg")
            let context = try #require(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8,
                bytesPerRow: 0, space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
            context.setFillColor(CGColor(red: 0.3, green: 0.6, blue: 0.9, alpha: 1))
            context.fill(CGRect(x: 0, y: 0, width: width, height: height))
            let image = try #require(context.makeImage())
            let destination = try #require(CGImageDestinationCreateWithURL(url as CFURL, UTType.jpeg.identifier as CFString, 1, nil))
            CGImageDestinationAddImage(destination, image, [kCGImagePropertyOrientation: orientation] as CFDictionary)
            #expect(CGImageDestinationFinalize(destination))
        }

        func remove() { try? FileManager.default.removeItem(at: directory) }
    }
}
