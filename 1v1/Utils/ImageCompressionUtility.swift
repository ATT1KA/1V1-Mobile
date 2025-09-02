import Foundation
import UIKit

final class ImageCompressionUtility {
    static let shared = ImageCompressionUtility()

    private init() {}

    struct CompressionResult {
        let data: Data
        let finalSize: Int
        let quality: CGFloat
        let didResize: Bool
    }

    /// Compress image progressively by trying quality levels and then resizing if necessary.
    func compressImageProgressively(image: UIImage, targetMaxBytes: Int) throws -> CompressionResult {
        let qualityLevels: [CGFloat] = [0.8, 0.6, 0.4, 0.2]

        // First try quality reductions without resizing
        for q in qualityLevels {
            if let data = image.jpegData(compressionQuality: q) {
                if data.count <= targetMaxBytes {
                    return CompressionResult(data: data, finalSize: data.count, quality: q, didResize: false)
                }
            }
        }

        // If still too large, attempt smart resizing while trying the quality levels
        var currentImage = image
        var didResize = false

        while currentImage.size.width > 400 && currentImage.size.height > 300 {
            didResize = true
            let newSize = CGSize(width: currentImage.size.width * 0.9, height: currentImage.size.height * 0.9)
            UIGraphicsBeginImageContextWithOptions(newSize, false, currentImage.scale)
            currentImage.draw(in: CGRect(origin: .zero, size: newSize))
            let resized = UIGraphicsGetImageFromCurrentImageContext()
            UIGraphicsEndImageContext()

            guard let resizedImage = resized else { break }
            currentImage = resizedImage

            for q in qualityLevels {
                if let data = currentImage.jpegData(compressionQuality: q) {
                    if data.count <= targetMaxBytes {
                        return CompressionResult(data: data, finalSize: data.count, quality: q, didResize: didResize)
                    }
                }
            }
        }

        // As a final attempt return best effort at lowest quality
        if let finalData = currentImage.jpegData(compressionQuality: 0.2) {
            return CompressionResult(data: finalData, finalSize: finalData.count, quality: 0.2, didResize: didResize)
        }

        throw NSError(domain: "ImageCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unable to compress image to target size"])
    }
}


