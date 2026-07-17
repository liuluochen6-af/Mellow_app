import UIKit
import Vision

@available(iOS 17.0, *)
class StickerService {
    static let shared = StickerService()

    private let cache = NSCache<NSString, UIImage>()

    private init() {
        cache.countLimit = 50
    }

    /// Remove background from image using Vision framework's VNGenerateForegroundInstanceMaskRequest
    func extractSubject(from image: UIImage) async -> UIImage? {
        guard let cgImage = image.cgImage else { return nil }

        return await withCheckedContinuation { continuation in
            let request = VNGenerateForegroundInstanceMaskRequest()
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])

            do {
                try handler.perform([request])
                guard let result = request.results?.first else {
                    continuation.resume(returning: nil)
                    return
                }

                let maskPixelBuffer = try result.generateScaledMaskForImage(forInstances: result.allInstances, from: handler)
                let maskedImage = applyMask(maskPixelBuffer, to: cgImage)
                continuation.resume(returning: maskedImage)
            } catch {
                print("Vision subject extraction failed: \(error)")
                continuation.resume(returning: nil)
            }
        }
    }

    /// Extract subject with caching by URL key
    func extractSubject(from image: UIImage, cacheKey: String) async -> UIImage? {
        let nsKey = cacheKey as NSString
        if let cached = cache.object(forKey: nsKey) {
            return cached
        }

        guard let result = await extractSubject(from: image) else { return nil }
        cache.setObject(result, forKey: nsKey)
        return result
    }

    private func applyMask(_ mask: CVPixelBuffer, to image: CGImage) -> UIImage? {
        let width = CVPixelBufferGetWidth(mask)
        let height = CVPixelBufferGetHeight(mask)

        CVPixelBufferLockBaseAddress(mask, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(mask, .readOnly) }

        guard let maskData = CVPixelBufferGetBaseAddress(mask) else { return nil }
        let maskBytesPerRow = CVPixelBufferGetBytesPerRow(mask)

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        // Draw the original image scaled to mask size
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let pixelData = context.data else { return nil }
        let pixels = pixelData.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Apply mask as alpha channel
        for y in 0..<height {
            for x in 0..<width {
                let maskOffset = y * maskBytesPerRow + x
                let pixelOffset = (y * width + x) * 4
                let maskValue = maskData.load(fromByteOffset: maskOffset, as: UInt8.self)
                pixels[pixelOffset + 3] = maskValue
            }
        }

        guard let maskedCGImage = context.makeImage() else { return nil }
        return UIImage(cgImage: maskedCGImage)
    }
}
