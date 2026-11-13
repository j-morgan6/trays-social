import SwiftUI

/// W257: what the Posted screen shows about the new post, built from the
/// post the create call returned. Pure so tests can check the title fallback
/// and the share URL without a view. The title is the one post detail shows
/// (PostDetailInfo, fallback "Untitled recipe"); cards share it for any
/// caption with a first sentence and differ only on an empty caption, where
/// cards say "Untitled".
struct PostedSummary {
    let post: Post
    let title: String
    let photoURL: URL?
    let authorName: String
    let authorAvatarURL: URL?
    let cookTime: String?
    let kind: RecipeCard.Kind
    /// The public /p/<id> page, the same URL post detail shares (D78).
    let shareURL: URL?
    /// W258: names of the collections the post was added to, in tap order.
    let addedTo: [String]

    /// W258: "Added to Weeknights and Soups", or nil when it went nowhere.
    var addedToLine: String? {
        guard !addedTo.isEmpty else { return nil }
        let names = addedTo.formatted(.list(type: .and))
        return String(localized: "Added to \(names)")
    }

    init(post: Post, baseURL: String = Configuration.apiBaseURL, addedTo: [String] = []) {
        self.post = post
        title = RecipeTitle.from(caption: post.caption, fallback: String(localized: "Untitled recipe"))
        photoURL = post.primaryPhotoURL?.asBackendURL
        authorName = post.user.username
        authorAvatarURL = post.user.profilePhotoUrl?.asBackendURL
        cookTime = CookTime.label(minutes: post.cookingTimeMinutes)
        kind = post.isRecipe ? .recipe : .photoPost
        shareURL = URL(string: baseURL + "/p/\(post.id)")
        self.addedTo = addedTo
    }
}

/// W257 (Create artboard, Posted state): shown in place of the editor after
/// a successful publish. A check, "Posted to your tray", the 7-day copy
/// (Home's new-from-follows window), a card of the new recipe, and View
/// recipe, Share and Done. W258: and, when the post was filed into
/// collections, which ones (the adds settle before this screen shows). The
/// end of a write, not a refresh path: nothing here loads data or toasts;
/// the card's photo loads like any card image and falls back silently.
/// Share is a ShareLink in this view's own hierarchy, never inside a menu,
/// so it presents.
struct PostedView: View {
    let summary: PostedSummary
    let onViewRecipe: () -> Void
    let onDone: () -> Void

    @ScaledMetric(relativeTo: .largeTitle) private var checkSize: CGFloat = 56

    // The 7 days match Home's new-from-follows window (@new_window_days, lib/trays_social/home.ex).
    // swiftlint:disable:next line_length
    private static let followersCopy = String(localized: "People who follow you will see it in New from people you follow for the next 7 days.")

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                Image(systemName: "checkmark.circle.fill")
                    .resizable()
                    .scaledToFit()
                    .frame(width: checkSize, height: checkSize)
                    .foregroundStyle(Theme.primaryInk)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(String(localized: "Posted to your tray"))
                        .roundedFont(.emptyHeadline)
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Text(Self.followersCopy)
                        .scaledFont(16, relativeTo: .body)
                        .foregroundStyle(Theme.muted)
                    if let addedToLine = summary.addedToLine {
                        Text(addedToLine)
                            .scaledFont(16, weight: .semibold, relativeTo: .body)
                            .foregroundStyle(Theme.text)
                    }
                }
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)

                RecipeCard(
                    title: summary.title,
                    photoURL: summary.photoURL,
                    authorName: summary.authorName,
                    authorAvatarURL: summary.authorAvatarURL,
                    cookTime: summary.cookTime,
                    kind: summary.kind
                )
                .frame(maxWidth: 320)

                actions
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
            .frame(maxWidth: .infinity)
        }
        .background(Theme.background)
    }

    private var actions: some View {
        VStack(spacing: 12) {
            Button(String(localized: "View recipe"), action: onViewRecipe)
                .buttonStyle(AuthCTAButtonStyle())

            if let shareURL = summary.shareURL {
                ShareLink(item: shareURL, subject: Text(summary.title), message: Text("From Trays")) {
                    Label(String(localized: "Share"), systemImage: "square.and.arrow.up")
                }
                .buttonStyle(AuthOutlineButtonStyle())
            }

            Button(String(localized: "Done"), action: onDone)
                .buttonStyle(AuthTextButtonStyle())
        }
    }
}
