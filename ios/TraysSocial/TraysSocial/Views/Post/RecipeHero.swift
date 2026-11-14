import SwiftUI

/// Recipe Detail hero: the photo (or carousel) under the floating Back,
/// Share and More controls.
///
/// W247: restyled to the Recipe artboard. A recipe's photo is 400pt high; a
/// legacy photo post's is square and carries a "Photo" tag. The title, the
/// byline and everything else sit on the sheet below (`RecipeHeadSheet`),
/// which rises 28pt over the bottom of the photo. Save moved to the bottom
/// action pill (`RecipeActionBar`).
struct RecipeHero: View {
    static let recipeHeight: CGFloat = 400
    /// How far the head sheet rises over the photo.
    static let sheetOverlap: CGFloat = 28

    let post: Post
    let onBack: () -> Void
    let shareURL: URL?
    /// W148: the overflow (ellipsis) menu lives on the hero's floating
    /// controls because the nav bar is hidden (`.toolbar(.hidden,...)`),
    /// so a toolbar menu would be unreachable. Delete shows only for the
    /// owner; Report stays available to everyone.
    var isOwner: Bool = false
    var onReport: () -> Void = {}
    var onEdit: () -> Void = {}
    var onDelete: () -> Void = {}

    var body: some View {
        photoFrame
            .overlay(alignment: .top) { floatingControls }
            .overlay(alignment: .bottomLeading) {
                if !post.isRecipe {
                    photoTag
                        .padding(.leading, HomeMetrics.inset)
                        .padding(.bottom, Self.sheetOverlap + 12)
                }
            }
            .clipped()
            .onAppear(perform: prefetchCarouselPhotos)
    }

    /// A recipe's photo is a fixed 400pt band; a legacy photo post's is
    /// square, as it was posted.
    @ViewBuilder
    private var photoFrame: some View {
        if post.isRecipe {
            Color.clear
                .containerRelativeFrame(.horizontal)
                .frame(height: Self.recipeHeight)
                .overlay { photo }
        } else {
            // Square at the width the scroll view offers; the photo inside
            // is pinned to the container width and clipped.
            Color.clear
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
                .overlay { photo }
        }
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

    @ViewBuilder
    private var photo: some View {
        if post.photos.count > 1 {
            TabView {
                ForEach(post.photos.sorted(by: { $0.position < $1.position }), id: \.position) { photo in
                    PhotoSlot(url: photo.url.asBackendURL, cornerRadius: 0)
                        .containerRelativeFrame(.horizontal)
                        .clipped()
                }
            }
            .tabViewStyle(.page)
        } else {
            PhotoSlot(url: post.primaryPhotoURL?.asBackendURL, cornerRadius: 0)
                .containerRelativeFrame(.horizontal)
                .clipped()
        }
    }

    private var photoTag: some View {
        Text("Photo")
            .scaledFont(11.5, weight: .bold, relativeTo: .caption)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(Capsule(style: .continuous).fill(Theme.surface))
            .shadow(color: Theme.shadow, radius: 1.5, y: 1)
    }

    private var floatingControls: some View {
        HStack {
            HeroCircleButton(icon: "chevron.left", label: String(localized: "Back"), action: onBack)
            Spacer()
            HStack(spacing: 8) {
                if let shareURL {
                    // D78: SwiftUI ShareLink presents the native iOS
                    // share sheet with the post URL — Universal Links
                    // on the receiver side land back in the app via
                    // AppState.handlePostDeepLink (see TraysSocialApp).
                    ShareLink(item: shareURL, subject: Text(Self.shareTitle(for: post)), message: Text("From Trays")) {
                        HeroCircleLabel(icon: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share recipe")
                }
                Menu {
                    if isOwner {
                        Button("Edit Post", action: onEdit)
                        Button("Delete Post", role: .destructive, action: onDelete)
                    }
                    Button("Report Post", role: .destructive, action: onReport)
                } label: {
                    HeroCircleLabel(icon: "ellipsis")
                }
                .accessibilityLabel("More options")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 56)
    }

    /// W266: the share subject is the recipe title only, never the full
    /// caption, with its own "A recipe on Trays" fallback. Internal so a test
    /// can pin that wiring.
    static func shareTitle(for post: Post) -> String {
        RecipeTitle.from(caption: post.caption, fallback: String(localized: "A recipe on Trays"))
    }
}

/// W247: the floating pill circle behind the hero controls (the canvas time
/// pill: material plus the pill token).
private struct HeroCircleLabel: View {
    let icon: String

    var body: some View {
        Image(systemName: icon)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(Theme.text)
            .frame(width: 46, height: 46)
            .background {
                ZStack {
                    Circle().fill(.ultraThinMaterial)
                    Circle().fill(Theme.pill)
                }
            }
            .overlay(Circle().strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .shadow(color: Theme.shadow, radius: 12, y: 8)
            .contentShape(Circle())
    }
}

/// Round translucent button — the hero's back control.
private struct HeroCircleButton: View {
    let icon: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HeroCircleLabel(icon: icon)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
