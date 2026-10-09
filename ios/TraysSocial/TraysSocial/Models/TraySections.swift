import Foundation

/// How My Tray groups its grid. Recipe-first splits by ownership (My recipes
/// / Saved); classic keeps the split by type (Recipes / Saved posts). Pure,
/// like `ShellLayout`, so the grouping is tested without a view.
enum TraySections {
    struct Section: Equatable {
        let title: String
        let posts: [Post]
    }

    /// Empty sections are dropped so the tray never shows a "· 0" header.
    /// A nil `currentUserId` (signed out) owns nothing, so every post is Saved.
    static func make(posts: [Post], currentUserId: Int?, recipeFirst: Bool) -> [Section] {
        let sections: [Section] = if recipeFirst {
            [
                Section(title: String(localized: "My recipes"), posts: posts.filter { $0.user.id == currentUserId }),
                Section(title: String(localized: "Saved"), posts: posts.filter { $0.user.id != currentUserId }),
            ]
        } else {
            [
                Section(title: String(localized: "Recipes"), posts: posts.filter(\.isRecipe)),
                Section(title: String(localized: "Saved posts"), posts: posts.filter { !$0.isRecipe }),
            ]
        }
        return sections.filter { !$0.posts.isEmpty }
    }

    /// Grid badge that marks a legacy photo-only post once the app is recipe-first.
    static func photoBadge(for post: Post, recipeFirst: Bool) -> String? {
        recipeFirst && !post.isRecipe ? String(localized: "Photo") : nil
    }
}
