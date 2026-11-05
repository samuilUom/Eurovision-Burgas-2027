import Foundation
import ImageIO
import UniformTypeIdentifiers

struct RestaurantImage: Sendable {
    let full: Data
    let thumbnail: Data
    // Downsample off the main thread and re-encode pixels, stripping EXIF/GPS.
    static func prepare(_ bytes: Data) -> RestaurantImage? {
        guard let source = CGImageSourceCreateWithData(bytes as CFData, nil) else { return nil }
        func encode(size: Int, maxBytes: Int) -> Data? {
            guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, [
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceCreateThumbnailWithTransform: true,
                kCGImageSourceThumbnailMaxPixelSize: size
            ] as CFDictionary) else { return nil }
            for quality in [0.8, 0.65, 0.5, 0.35] {
                let data = NSMutableData()
                guard let target = CGImageDestinationCreateWithData(data, UTType.jpeg.identifier as CFString, 1, nil) else { return nil }
                CGImageDestinationAddImage(target, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
                if CGImageDestinationFinalize(target), data.length <= maxBytes { return data as Data }
            }
            return nil
        }
        guard let full = encode(size: 1280, maxBytes: RestaurantContribution.maxPhotoBytes),
              let thumbnail = encode(size: 500, maxBytes: RestaurantContribution.maxThumbnailBytes) else { return nil }
        return RestaurantImage(full: full, thumbnail: thumbnail)
    }
}
