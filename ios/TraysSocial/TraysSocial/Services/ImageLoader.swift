import Foundation
import UIKit

/// Single source of truth for HTTP image loading.
///
/// ## Why this exists
///
/// Stock `AsyncImage(url:)` instantiates a fresh `URLSession` task per
/// view. A 3-up profile grid scrolling 30 cells therefore races up to
/// 30 concurrent loads of the same URL when the user paginates back
/// to the top — no dedup, no shared in-memory bitmap cache, and
/// stutter every time. `ImageLoader` fixes both halves:
///
///   1. **Dedup** — concurrent calls for the same URL share a single
///      in-flight `Task`. The first caller does the network work; all
///      others suspend on `.value` of the same future. The Task is
///      removed from the in-flight map when it finishes.
///
///   2. **Cache** — once a `UIImage` is decoded it's stored in an
///      `NSCache<NSURL, UIImage>` (cost-bounded, LRU, evicts under
///      memory pressure automatically). The underlying HTTP response
///      is also cached by `URLCache.shared` so a cold restart still
///      gets a fast load.
///
/// `URLCache.shared` already respects `Cache-Control` headers on the
/// backend's `/uploads/` responses — we don't override that, per the
/// W130 pitfall about not ignoring HTTP cache directives.
///
/// ## Concurrency
///
/// Marked `@unchecked Sendable` because NSCache isn't formally
/// Sendable in Swift 6 strict mode, but it is internally thread-safe
/// (Apple docs guarantee atomic setObject/objectForKey). Mutations to
/// the in-flight Task map are guarded by an NSLock.
final class ImageLoader: @unchecked Sendable {
    static let shared = ImageLoader()

    private let memoryCache: NSCache<NSURL, UIImage>
    private let session: URLSession
    private let lock = NSLock()
    private var inFlight: [URL: Task<UIImage, Error>] = [:]

    init() {
        let config = URLSessionConfiguration.default
        config.urlCache = URLCache.shared
        config.requestCachePolicy = .useProtocolCachePolicy
        session = URLSession(configuration: config)

        let cache = NSCache<NSURL, UIImage>()
        // Cost in bytes (rough) — give us ~50 thumbnails worth of
        // headroom before NSCache starts evicting.
        cache.countLimit = 200
        cache.totalCostLimit = 64 * 1024 * 1024
        memoryCache = cache
    }

    /// Synchronous cache probe. Returns the cached UIImage if one is
    /// already decoded for this URL, otherwise nil. Used by
    /// `CachedAsyncImage` so the first render is instant on a cache
    /// hit.
    func cachedImage(for url: URL) -> UIImage? {
        memoryCache.object(forKey: url as NSURL)
    }

    /// Fetch (and decode) the image at `url`. Concurrent calls for
    /// the same URL all suspend on the same in-flight Task; the
    /// network request fires exactly once.
    func load(url: URL) async throws -> UIImage {
        if let cached = memoryCache.object(forKey: url as NSURL) {
            return cached
        }

        let task = taskForLoading(url: url)
        return try await task.value
    }

    /// Sync helper that owns the lock so we never hold an NSLock
    /// across an `await`. Either returns an existing in-flight Task
    /// for `url` or creates and registers a new one.
    private func taskForLoading(url: URL) -> Task<UIImage, Error> {
        lock.lock()
        defer { lock.unlock() }

        if let existing = inFlight[url] {
            return existing
        }
        let task = Task<UIImage, Error> { [self] in
            let result = await fetchAndDecode(url: url)
            clearInFlight(url: url)
            return try result.get()
        }
        inFlight[url] = task
        return task
    }

    private func clearInFlight(url: URL) {
        lock.lock()
        defer { lock.unlock() }
        inFlight[url] = nil
    }

    private func isInFlight(url: URL) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return inFlight[url] != nil
    }

    /// Fire-and-forget prefetch. Callers (typically a `LazyVGrid`
    /// row's `.onAppear`) use this to warm the cache for cells about
    /// to scroll into view. Errors are swallowed — a missed prefetch
    /// is no worse than no prefetch.
    func prefetch(urls: [URL]) {
        for url in urls {
            if memoryCache.object(forKey: url as NSURL) != nil { continue }
            if isInFlight(url: url) { continue }
            Task { try? await load(url: url) }
        }
    }

    private func fetchAndDecode(url: URL) async -> Result<UIImage, Error> {
        do {
            let (data, _) = try await session.data(from: url)
            guard let image = UIImage(data: data) else {
                return .failure(ImageLoaderError.decodeFailed)
            }
            let cost = image.cgImage.map { Int($0.bytesPerRow * $0.height) } ?? 1
            memoryCache.setObject(image, forKey: url as NSURL, cost: cost)
            return .success(image)
        } catch {
            return .failure(error)
        }
    }
}

enum ImageLoaderError: Error {
    case decodeFailed
}
