import SwiftUI
import UIKit
import Combine

struct CachedRemoteImage<Content: View, Placeholder: View>: View {
    let url: URL?
    let cacheKey: String?
    let content: (Image) -> Content
    let placeholder: () -> Placeholder

    @StateObject private var loader = Loader()

    private var resolvedCacheKey: String {
        if let cacheKey, !cacheKey.isEmpty {
            return cacheKey
        }
        return url?.absoluteString ?? "cached-remote-image-empty"
    }

    var body: some View {
        Group {
            if let image = loader.image {
                content(Image(uiImage: image))
            } else {
                placeholder()
            }
        }
        .task(id: resolvedCacheKey) {
            await loader.load(url: url, cacheKey: resolvedCacheKey)
        }
    }
}

@MainActor
private final class Loader: ObservableObject {
    @Published var image: UIImage?
    private var lastCacheKey: String?

    private static let cache = NSCache<NSString, UIImage>()

    func load(url: URL?, cacheKey: String) async {
        if lastCacheKey == cacheKey, image != nil {
            return
        }
        lastCacheKey = cacheKey

        guard let url else {
            image = nil
            return
        }

        if let cachedImage = Self.cache.object(forKey: cacheKey as NSString) {
            image = cachedImage
            return
        }

        var request = URLRequest(url: url)
        request.cachePolicy = .returnCacheDataElseLoad
        request.timeoutInterval = 30

        do {
            let (data, _) = try await URLSession.shared.data(for: request)
            guard let loadedImage = UIImage(data: data) else {
                image = nil
                return
            }
            Self.cache.setObject(loadedImage, forKey: cacheKey as NSString)
            image = loadedImage
        } catch {
            image = nil
        }
    }
}
