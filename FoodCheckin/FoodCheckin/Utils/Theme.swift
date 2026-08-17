import SwiftUI
import UIKit

enum Theme {
    static let background = Color.white
    static let surface = Color(UIColor.systemGray6)
    static let primary = Color.black
    static let secondary = Color(UIColor.systemGray)
    static let accent = Color.black
    static let textPrimary = Color.black
    static let textSecondary = Color(UIColor.systemGray)
    static let cardBackground = Color.white
    static let cardShadow = Color.black.opacity(0.06)
    static let border = Color(UIColor.systemGray4)
    static let tagBackground = Color(UIColor.systemGray6)
}

actor RemoteImageCache {
    static let shared = RemoteImageCache()

    private let cache = NSCache<NSURL, UIImage>()
    private var requests: [URL: Task<UIImage?, Never>] = [:]

    private init() {
        cache.countLimit = 60
        cache.totalCostLimit = 80 * 1_024 * 1_024
    }

    func image(for url: URL) async -> UIImage? {
        if let image = cache.object(forKey: url as NSURL) {
            return image
        }
        if let request = requests[url] {
            return await request.value
        }

        let request: Task<UIImage?, Never> = Task.detached(priority: .utility) {
            var urlRequest = URLRequest(url: url)
            urlRequest.cachePolicy = .returnCacheDataElseLoad
            guard let (data, response) = try? await URLSession.shared.data(for: urlRequest),
                  let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return nil
            }
            return UIImage(data: data)
        }
        requests[url] = request

        let image = await request.value
        requests[url] = nil
        if let image {
            let cost = Int(image.size.width * image.size.height * 4)
            cache.setObject(image, forKey: url as NSURL, cost: cost)
        }
        return image
    }
}

@MainActor
private final class CachedImageLoader: ObservableObject {
    @Published var image: UIImage?
    private var currentURL: URL?

    func load(_ url: URL?) async {
        guard let url else {
            currentURL = nil
            image = nil
            return
        }
        guard currentURL != url || image == nil else { return }

        currentURL = url
        image = nil
        let loadedImage = await RemoteImageCache.shared.image(for: url)
        guard currentURL == url, !Task.isCancelled else { return }
        image = loadedImage
    }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder
    @StateObject private var loader = CachedImageLoader()

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: url) {
            await loader.load(url)
        }
    }
}
