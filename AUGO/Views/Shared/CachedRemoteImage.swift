import SwiftUI
import UIKit
import Combine
import ImageIO

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
                    .modifier(SkeletonShimmer())
            }
        }
        .task(id: resolvedCacheKey) {
            await loader.load(url: url, cacheKey: resolvedCacheKey)
        }
    }
}

private struct SkeletonShimmer: ViewModifier {
    @State private var shimmerOffset: CGFloat = -1.2

    func body(content: Content) -> some View {
        content
            .overlay {
                GeometryReader { proxy in
                    let width = max(proxy.size.width, 1)
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.00),
                            Color.white.opacity(0.22),
                            Color.white.opacity(0.00)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                    .frame(width: width * 0.52)
                    .rotationEffect(.degrees(16))
                    .offset(x: shimmerOffset * width * 2.2)
                    .animation(.linear(duration: 1.05).repeatForever(autoreverses: false), value: shimmerOffset)
                    .onAppear {
                        shimmerOffset = 1.2
                    }
                }
                .allowsHitTesting(false)
            }
    }
}

@MainActor
private final class Loader: ObservableObject {
    @Published var image: UIImage?
    private var lastCacheKey: String?
    private var currentTask: Task<Void, Never>?

    deinit {
        currentTask?.cancel()
    }

    func load(url: URL?, cacheKey: String) async {
        if lastCacheKey == cacheKey, image != nil {
            return
        }
        currentTask?.cancel()
        lastCacheKey = cacheKey

        guard let url else {
            image = nil
            return
        }

        image = nil

        currentTask = Task { [weak self] in
            guard let self else { return }
            let loadedImage = await RemoteImagePipeline.shared.image(for: url, cacheKey: cacheKey)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard self.lastCacheKey == cacheKey else { return }
                self.image = loadedImage
            }
        }
        await currentTask?.value
    }
}

actor RemoteImagePipeline {
    static let shared = RemoteImagePipeline()

    private let imageCache = NSCache<NSString, UIImage>()
    private let session: URLSession
    private var inFlight: [String: Task<UIImage?, Never>] = [:]

    init() {
        imageCache.countLimit = 500
        imageCache.totalCostLimit = 160 * 1024 * 1024

        let config = URLSessionConfiguration.default
        // Respect server cache headers/ETag to avoid serving stale images for too long.
        config.requestCachePolicy = .useProtocolCachePolicy
        config.urlCache = URLCache(
            memoryCapacity: 64 * 1024 * 1024,
            diskCapacity: 512 * 1024 * 1024,
            diskPath: "augo-image-cache"
        )
        config.timeoutIntervalForRequest = 30
        config.httpMaximumConnectionsPerHost = 8
        session = URLSession(configuration: config)
    }

    func image(for url: URL, cacheKey: String) async -> UIImage? {
        if let cached = imageCache.object(forKey: cacheKey as NSString) {
            return cached
        }

        if let task = inFlight[cacheKey] {
            return await task.value
        }

        let task = Task<UIImage?, Never> { [session] in
            var request = URLRequest(url: url)
            request.cachePolicy = .useProtocolCachePolicy
            request.timeoutInterval = 30

            do {
                let (data, response) = try await session.data(for: request)
                guard let httpResponse = response as? HTTPURLResponse,
                      (200..<300).contains(httpResponse.statusCode) else {
                    return nil
                }
                return Self.downsampledImage(from: data, maxPixelSize: 1400)
            } catch {
                return nil
            }
        }

        inFlight[cacheKey] = task
        let image = await task.value
        inFlight[cacheKey] = nil

        if let image {
            imageCache.setObject(image, forKey: cacheKey as NSString, cost: Self.estimatedCost(of: image))
        }
        return image
    }

    private static func downsampledImage(from data: Data, maxPixelSize: CGFloat) -> UIImage? {
        let sourceOptions: [CFString: Any] = [
            kCGImageSourceShouldCache: false
        ]
        guard let source = CGImageSourceCreateWithData(data as CFData, sourceOptions as CFDictionary) else {
            return UIImage(data: data)
        }

        let downsampleOptions: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize
        ]
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, downsampleOptions as CFDictionary) else {
            return UIImage(data: data)
        }
        return UIImage(cgImage: cgImage)
    }

    private static func estimatedCost(of image: UIImage) -> Int {
        let width = Int(image.size.width * image.scale)
        let height = Int(image.size.height * image.scale)
        return max(1, width * height * 4)
    }
}
