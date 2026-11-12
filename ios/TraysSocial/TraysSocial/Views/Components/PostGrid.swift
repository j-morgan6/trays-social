import SwiftUI

/// W245: a post as the shared RecipeCard in My Tray, a collection and a
/// cook's tray. Every grid is 4:3, so cards in a row are the same size (the
/// user's rule). A legacy photo-only post keeps the same footprint with the
/// "Photo" tag; like the old grid badge, the tag shows only when recipe-first
/// is on.
struct PostRecipeCard: View {
    let post: Post
    /// Overrides the post's username, as My recipes does with "You".
    var authorName: String?
    var context: String?
    var showsAuthor = true

    var body: some View {
        RecipeCard(
            title: RecipeTitle.from(caption: post.caption),
            photoURL: post.primaryPhotoURL?.asBackendURL,
            authorName: authorName ?? post.user.username,
            authorAvatarURL: post.user.profilePhotoUrl?.asBackendURL,
            context: context,
            cookTime: CookTime.label(minutes: post.cookingTimeMinutes),
            kind: Self.kind(for: post, recipeFirst: FeatureFlags.shared.recipeFirst),
            showsAuthor: showsAuthor
        )
    }

    static func kind(for post: Post, recipeFirst: Bool) -> RecipeCard.Kind {
        TraySections.photoBadge(for: post, recipeFirst: recipeFirst) == nil ? .recipe : .photoPost
    }
}

/// The two-column grid every W245 list uses.
enum PostGrid {
    static let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]
    static let spacing: CGFloat = 12
}
