import SwiftUI

/// W247: what the recipe detail scroll view shows for a loaded post: the
/// hero, the head sheet, the recipe body (recipes only), tags and notes.
/// Pulled out of PostDetailView so the preview galleries can render every
/// state without a view model.
struct PostDetailContent: View {
    struct Actions {
        var onBack: () -> Void = {}
        var onOpenAuthor: () -> Void = {}
        var onToggleLike: () -> Void = {}
        var onToggleBookmark: () -> Void = {}
        var onReport: () -> Void = {}
        var onEdit: () -> Void = {}
        var onDelete: () -> Void = {}
        var onRetryComments: () -> Void = {}
    }

    struct CommentsState {
        var comments: [Comment] = []
        var isLoading = false
        var loadAttempted = true
        var error: Error?
    }

    let post: Post
    var isOwner = false
    var comments = CommentsState()
    var actions = Actions()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                RecipeHero(
                    post: post,
                    onBack: actions.onBack,
                    shareURL: URL(string: Configuration.apiBaseURL + "/p/\(post.id)"),
                    isOwner: isOwner,
                    onReport: actions.onReport,
                    onEdit: actions.onEdit,
                    onDelete: actions.onDelete
                )

                RecipeHeadSheet(
                    post: post,
                    onOpenAuthor: actions.onOpenAuthor,
                    onToggleLike: actions.onToggleLike
                )

                if post.isRecipe {
                    RecipeBodySection(post: post)
                }

                if !post.tags.isEmpty {
                    PostTagsRow(tags: post.tags)
                }

                CommentsSection(
                    post: post,
                    comments: comments.comments,
                    isLoading: comments.isLoading,
                    loadAttempted: comments.loadAttempted,
                    error: comments.error,
                    onRetry: actions.onRetryComments
                )

                // Room for the action pill and the comment bar.
                Spacer().frame(height: 150)
            }
            .containerRelativeFrame(.horizontal, alignment: .leading)
        }
    }
}

/// W247: the post's tags as quiet lift chips.
struct PostTagsRow: View {
    let tags: [String]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Array(tags.enumerated()), id: \.offset) { _, tag in
                    Text(verbatim: "#\(tag)")
                        .scaledFont(13, weight: .semibold, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .background(Capsule(style: .continuous).fill(Theme.lift))
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
            .padding(.vertical, 12)
        }
        .padding(.top, 12)
    }
}

/// W247: the floating bottom pill (Recipe artboard): Save, or Edit on your
/// own post, and the amber Cook mode button when the recipe has steps.
struct RecipeActionBar: View {
    let isOwner: Bool
    let isSaved: Bool
    let showsCookMode: Bool
    var onToggleSave: () -> Void = {}
    var onEdit: () -> Void = {}
    var onCookMode: () -> Void = {}

    var body: some View {
        HStack(spacing: 6) {
            if isOwner {
                Button(action: onEdit) {
                    Label(String(localized: "Edit"), systemImage: "pencil")
                        .modifier(ActionPillLabel(fill: .clear, foreground: Theme.text))
                }
                .buttonStyle(.plain)
            } else {
                Button(action: onToggleSave) {
                    Label(
                        isSaved ? String(localized: "Saved") : String(localized: "Save"),
                        systemImage: isSaved ? "bookmark.fill" : "bookmark"
                    )
                    .modifier(ActionPillLabel(
                        fill: isSaved ? Theme.mintTint : .clear,
                        foreground: isSaved ? Theme.primaryInk : Theme.text
                    ))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(isSaved ? .isSelected : [])
            }
            if showsCookMode {
                Button(action: onCookMode) {
                    Label(String(localized: "Cook mode"), systemImage: "frying.pan")
                        .modifier(ActionPillLabel(fill: Theme.accent, foreground: Theme.inkOnAccent))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(5)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Theme.pill)
            }
        }
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 12, y: 8)
    }
}

/// One button inside the action pill: a 44pt capsule.
private struct ActionPillLabel: ViewModifier {
    let fill: Color
    let foreground: Color

    func body(content: Content) -> some View {
        content
            .scaledFont(15, weight: .semibold, relativeTo: .body)
            .foregroundStyle(foreground)
            .lineLimit(1)
            .padding(.leading, 12)
            .padding(.trailing, 16)
            .frame(minHeight: 44)
            .background(Capsule(style: .continuous).fill(fill))
            .contentShape(Capsule(style: .continuous))
    }
}
