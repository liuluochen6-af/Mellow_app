import UIKit
import Vision
import ImageIO
import CryptoKit

@available(iOS 17.0, *)
actor StickerService {
    static let shared = StickerService()

    private let cache = NSCache<NSString, UIImage>()
    private let diskDirectory: URL
    private let maxDimension = 512

    private init() {
        cache.countLimit = 20
        cache.totalCostLimit = 24 * 1024 * 1024

        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskDirectory = caches.appendingPathComponent("Stickers", isDirectory: true)
        try? FileManager.default.createDirectory(at: diskDirectory, withIntermediateDirectories: true)
    }

    /// Returns a memory/disk cached sticker, or downloads a downsampled source
    /// and performs Vision extraction serially on this actor.
    func sticker(from url: URL, cacheKey: String) async -> UIImage? {
        let nsKey = cacheKey as NSString
        if let cached = cache.object(forKey: nsKey) {
            return cached
        }

        let diskURL = fileURL(for: cacheKey)
        if let image = UIImage(contentsOfFile: diskURL.path) {
            insertIntoMemory(image, key: nsKey)
            return image
        }

        guard !Task.isCancelled,
              let (data, _) = try? await URLSession.shared.data(from: url),
              !Task.isCancelled,
              let image = downsample(data: data),
              let result = extractSubject(from: image),
              !Task.isCancelled else {
            return nil
        }

        insertIntoMemory(result, key: nsKey)
        if let png = result.pngData() {
            try? png.write(to: diskURL, options: .atomic)
        }
        return result
    }

    private func downsample(data: Data) -> UIImage? {
        guard let source = CGImageSourceCreateWithData(data as CFData, nil) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxDimension,
            kCGImageSourceShouldCacheImmediately: true,
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else {
            return nil
        }
        return UIImage(cgImage: cgImage)
    }

    private func extractSubject(from image: UIImage) -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }
        let request = VNGenerateForegroundInstanceMaskRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

        do {
            try handler.perform([request])
            guard let result = request.results?.first else { return nil }
            let mask = try result.generateScaledMaskForImage(
                forInstances: result.allInstances,
                from: handler
            )
            return applyMask(mask, to: cgImage)
        } catch {
            return nil
        }
    }

    private func insertIntoMemory(_ image: UIImage, key: NSString) {
        let pixels = Int(image.size.width * image.scale * image.size.height * image.scale)
        cache.setObject(image, forKey: key, cost: pixels * 4)
    }

    private func fileURL(for key: String) -> URL {
        let digest = SHA256.hash(data: Data(key.utf8))
        let name = digest.map { String(format: "%02x", $0) }.joined()
        return diskDirectory.appendingPathComponent(name).appendingPathExtension("png")
    }

    private func applyMask(_ mask: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let maskOffset = y * maskBytesPerRow + x
                let pixelOffset = (y * width + x) * 4
                pixels[pixelOffset + 3] = maskData.load(fromByteOffset: maskOffset, as: UInt8.self)
            }
        }

        guard let masked = context.makeImage() else { return nil }
        return UIImage(cgImage: masked)
    }
}
