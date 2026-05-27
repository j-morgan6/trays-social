import SwiftUI

/// Drop-in replacement for SwiftUI's `AsyncImage(url:content:placeholder:)`
/// backed by the shared `ImageLoader`. Cache hits render synchronously
/// on first body invocation — no spinner flash for a URL we've seen.
///
/// ## Preserving the D34 cache-invalidation hook
///
/// Callers should still attach `.id(url)` to the resulting view when
/// the URL can change for the same logical entity (e.g. a user
/// uploading a new profile photo). The internal cache is keyed by
/// absolute URL, so a new URL is already a new cache key — but
/// SwiftUI's view identity layer also has to refresh. The `.id(url)`
/// idiom forces that and stays the project's convention.
struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    let url: URL?
    @ViewBuilder let content: (Image) -> Content
    @ViewBuilder let placeholder: () -> Placeholder

    @State private var loadedImage: UIImage?

    var body: some View {
        Group {
            if let image = loadedImage {
                content(Image(uiImage: image))
            } else {
                placeholder()
                    .task(id: url) {
                        await load()
                    }
            }
        }
    }

    private func load() async {
        guard let url else { return }

        // Synchronous cache probe so a warm hit renders without a
        // visible placeholder flicker.
        if let cached = ImageLoader.shared.cachedImage(for: url) {
            loadedImage = cached
            return
        }

        do {
            let image = try await ImageLoader.shared.load(url: url)
            // Guard against the cell scrolling off-screen mid-fetch —
            // SwiftUI cancels the .task; we only assign if still alive.
            if !Task.isCancelled {
                loadedImage = image
            }
        } catch {
            // Silent — caller's placeholder() stays visible. A toast
            // for every off-screen image failure would be noisy.
        }
    }
}
