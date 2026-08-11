import Foundation
import ImageIO
import UniformTypeIdentifiers

enum ImageProcessingError: LocalizedError {
    case unsupported
    case couldNotDecode
    case couldNotEncode

    var errorDescription: String? {
        switch self {
        case .unsupported:
            String(localized: "The selected file is not a supported image.")
        case .couldNotDecode:
            String(localized: "The image could not be read.")
        case .couldNotEncode:
            String(localized: "The image could not be saved.")
        }
    }
}

enum ImageProcessor {
    static let maximumPixelDimension = 1_600

    static func normalizedJPEGData(from data: Data) throws -> Data {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else {
            throw ImageProcessingError.unsupported
        }

        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maximumPixelDimension,
            kCGImageSourceShouldCacheImmediately: true
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(
            source,
            0,
            options as CFDictionary
        ) else {
            throw ImageProcessingError.couldNotDecode
        }

        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else {
            throw ImageProcessingError.couldNotEncode
        }

        let properties: [CFString: Any] = [
            kCGImageDestinationLossyCompressionQuality: 0.85
        ]
        CGImageDestinationAddImage(destination, image, properties as CFDictionary)
        guard CGImageDestinationFinalize(destination) else {
            throw ImageProcessingError.couldNotEncode
        }
        return output as Data
    }
}
