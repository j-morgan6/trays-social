import SwiftUI

/// Recipe Detail hero — photo with overlaid title + eyebrow + floating
/// controls. Mirrors `IOSRecipe`'s hero block from the Claude Design
/// handoff (design/handoff/trays-social/project/ios-screens.jsx).
///
/// Top of the photo: floating back / share / bookmark buttons.
/// Bottom of the photo: mono category eyebrow + SF 30pt title, on a
/// dark gradient that fades into the photo.
struct RecipeHero: View {
    let post: Post
    let bookmarked: Bool
    let onBack: () -> Void
    let shareURL: URL?
    let onBookmark: () -> Void

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            photo
            gradient
            floatingControls
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            titleBlock
        }
        .frame(height: 360)
        .clipped()
        .onAppear(perform: prefetchCarouselPhotos)
    }

    /// W130: warm the shared image cache for the rest of the carousel
    /// the moment the hero appears. The first photo is already loading
    /// via CachedAsyncImage; this pulls the next few so a left-swipe
    /// gets an instant render.
    private func prefetchCarouselPhotos() {
        guard post.photos.count > 1 else { return }
        let urls = post.photos
            .sorted(by: { $0.position < $1.position })
            .dropFirst()
            .prefix(4)
            .compactMap(\.url.asBackendURL)
        ImageLoader.shared.prefetch(urls: Array(urls))
    }

    private var photo: some View {
        Group {
            if post.photos.count > 1 {
                TabView {
                    ForEach(post.photos.sorted(by: { $0.position < $1.position }), id: \.position) { photo in
                        CachedAsyncImage(url: photo.url.asBackendURL) { image in
                            image.resizable().scaledToFill()
                        } placeholder: {
                            Rectangle().fill(Color(.systemGray5))
                        }
                        .containerRelativeFrame(.horizontal)
                        .frame(height: 360)
                        .clipped()
                    }
                }
                .tabViewStyle(.page)
            } else if let url = post.primaryPhotoURL {
                CachedAsyncImage(url: url.asBackendURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .containerRelativeFrame(.horizontal)
                .frame(height: 360)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray5))
            }
        }
    }

    private var gradient: some View {
        LinearGradient(
            colors: [
                .black.opacity(0.4),
                .clear,
                .clear,
                .black.opacity(0.85),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var floatingControls: some View {
        HStack {
            CircleButton(icon: "chevron.left", action: onBack)
            Spacer()
            HStack(spacing: 8) {
                if let shareURL {
                    // D78: SwiftUI ShareLink presents the native iOS
                    // share sheet with the post URL — Universal Links
                    // on the receiver side land back in the app via
                    // AppState.handlePostDeepLink (see TraysSocialApp).
                    ShareLink(item: shareURL, subject: Text(shareTitle), message: Text("From Trays")) {
                        Image(systemName: "square.and.arrow.up")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                            .frame(width: 38, height: 38)
                            .background(.ultraThinMaterial)
                            .clipShape(Circle())
                    }
                    .accessibilityLabel("Share recipe")
                }
                CircleButton(
                    icon: bookmarked ? "bookmark.fill" : "bookmark",
                    tint: bookmarked ? Theme.accent : .white,
                    action: onBookmark
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    private var shareTitle: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "A recipe on Trays" : candidate
    }

    private var titleBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            if let eyebrow = eyebrowText {
                Text(eyebrow)
                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .tracking(2)
            }

            Text(titleText)
                .font(.system(size: 30, weight: .bold))
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 18)
    }

    // MARK: - Derived

    private var titleText: String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    /// First 3 tags as a "·"-separated breadcrumb. Same convention the
    /// web recipe detail uses for its category eyebrow.
    private var eyebrowText: String? {
        guard !post.tags.isEmpty else { return nil }
        return post.tags.prefix(3).joined(separator: " · ").uppercased()
    }
}

/// Round translucent button — used for the floating back / share /
/// bookmark controls on the recipe hero.
private struct CircleButton: View {
    let icon: String
    var tint: Color = .white
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundStyle(tint)
                .frame(width: 38, height: 38)
                .background(.ultraThinMaterial)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }
}
