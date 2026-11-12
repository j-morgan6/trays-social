import Foundation

/// W247: what a failed recipe load says. A 404 means the post is gone, so it
/// says so and offers no retry; anything else is treated as a connection
/// problem. The view model logs the failure; this never toasts.
struct PostLoadErrorCopy: Equatable {
    let title: String
    let subtitle: String
    let allowsRetry: Bool

    static func decide(notFound: Bool) -> PostLoadErrorCopy {
        if notFound {
            return PostLoadErrorCopy(
                title: String(localized: "Post not available"),
                subtitle: String(localized: "It may have been removed or the link is wrong."),
                allowsRetry: false
            )
        }
        return PostLoadErrorCopy(
            title: String(localized: "Couldn't load this post"),
            subtitle: String(localized: "Check your connection and try again."),
            allowsRetry: true
        )
    }

    static func decide(error: Error) -> PostLoadErrorCopy {
        if case .notFound = error as? APIError {
            return decide(notFound: true)
        }
        return decide(notFound: false)
    }
}

/// W247: the recipe detail head sheet copy: the meta capsules (time,
/// servings, ingredient count), the kicker and the cook's note label. A
/// capsule shows only when the recipe has that value; servings are
/// read-only.
enum RecipeMeta {
    struct Capsule: Equatable, Identifiable {
        let systemImage: String
        let text: String

        var id: String {
            systemImage
        }
    }

    static func capsules(for post: Post) -> [Capsule] {
        capsules(minutes: post.cookingTimeMinutes, servings: post.servings, ingredientCount: post.ingredients.count)
    }

    /// W249: the same row for the recipe editor's preview, which has no `Post`.
    static func capsules(minutes: Int?, servings: Int?, ingredientCount: Int) -> [Capsule] {
        var capsules: [Capsule] = []
        if let minutes {
            capsules.append(Capsule(systemImage: "clock", text: timeLabel(minutes: minutes)))
        }
        if let servings {
            capsules.append(Capsule(systemImage: "person.2", text: String(localized: "Serves \(servings)")))
        }
        if ingredientCount > 0 {
            let count = ingredientCount
            let text = count == 1
                ? String(localized: "1 ingredient")
                : String(localized: "\(count) ingredients")
            capsules.append(Capsule(systemImage: "list.bullet", text: text))
        }
        return capsules
    }

    /// `CookTime.label`, except that a recorded 0 still reads "0 min" here as
    /// it did before W247 (cards hide it; the detail meta row never did).
    static func timeLabel(minutes: Int) -> String {
        CookTime.label(minutes: minutes) ?? String(localized: "\(minutes) min")
    }

    /// The kicker over the title: the recipe's first three tags, or nothing.
    static func kicker(tags: [String]) -> String? {
        let shown = tags.prefix(3).filter { !$0.isEmpty }
        return shown.isEmpty ? nil : shown.joined(separator: " · ")
    }

    /// The cook's note label: "From <cook>".
    static func noteLabel(username: String) -> String {
        String(localized: "From \(username)")
    }
}

/// W247: Cook mode's recipe line: "Title · serves N", or the title alone
/// when the recipe has no servings.
enum CookModeCopy {
    static func recipeLine(title: String, servings: Int?) -> String {
        guard let servings else { return title }
        return String(localized: "\(title) · serves \(servings)")
    }
}
