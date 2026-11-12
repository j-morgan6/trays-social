import SwiftUI

// MARK: - Comments section

/// Comments slot ported out of PostDetailView so its loading / error /
/// empty branches don't push the parent struct past SwiftLint's
/// type-body ceiling. Renders a heading + one of four branches: skeleton
/// (loading), inline retry (error), empty copy (loaded and zero comments),
/// or the per-comment list.
///
/// The skeleton uses a short delay before appearing so a fast-cached
/// fetch (50ms or less) doesn't flash skeleton rows — per W115's
/// pitfall on transition feel.
///
/// W247: restyled to the Recipe artboard (rounded heading, AvatarSlot rows,
/// mint COOK chip). A failed load stays inline with Try again, never a toast.
struct CommentsSection: View {
    let post: Post
    let comments: [Comment]
    let isLoading: Bool
    let loadAttempted: Bool
    let error: Error?
    let onRetry: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var skeletonVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.horizontal, HomeMetrics.inset)

            content
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.18), value: isLoading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Notes")
                .roundedFont(.section)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: "\(comments.count)")
                .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
        }
    }

    @ViewBuilder
    private var content: some View {
        if error != nil, comments.isEmpty {
            errorSurface
        } else if isLoading, comments.isEmpty {
            loadingSurface
                .transition(.opacity)
        } else if loadAttempted, comments.isEmpty {
            emptySurface
        } else {
            VStack(alignment: .leading, spacing: 18) {
                ForEach(comments) { comment in
                    CommentRow(comment: comment, post: post)
                }
            }
            .transition(.opacity)
        }
    }

    private var loadingSurface: some View {
        VStack(spacing: 6) {
            ForEach(0 ..< 3, id: \.self) { _ in
                // Match CommentRow's 28pt avatar.
                SkeletonListRow(avatarSize: 28)
            }
        }
        .opacity(skeletonVisible ? 1 : 0)
        .skeletonGroup(label: String(localized: "Loading notes"))
        .task {
            // Wait 220ms before showing skeletons — a fast-cached
            // /posts/:id/comments returns in well under 200ms and the
            // brief flash of skeleton would feel worse than no
            // indicator at all.
            try? await Task.sleep(for: .milliseconds(220))
            guard !Task.isCancelled else { return }
            // Crossfade in rather than snapping (D101). Reduce Motion
            // shows it instantly.
            if reduceMotion {
                skeletonVisible = true
            } else {
                withAnimation(.easeInOut(duration: 0.18)) { skeletonVisible = true }
            }
        }
    }

    private var emptySurface: some View {
        VStack(spacing: 6) {
            Text("No notes yet.")
                .roundedFont(.endHeadline)
                .foregroundStyle(Theme.text)
            Text("Be the first to leave one.")
                .scaledFont(13.5, relativeTo: .footnote)
                .foregroundStyle(Theme.muted)
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
        .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Theme.creamOrLift))
        .padding(.horizontal, HomeMetrics.inset)
    }

    private var errorSurface: some View {
        VStack(spacing: 12) {
            Text("Couldn't load notes.")
                .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.text)
            Button(action: onRetry) {
                Label(String(localized: "Try again"), systemImage: "arrow.clockwise")
            }
            .buttonStyle(.traySecondary)
            .accessibilityLabel(Text("Retry loading notes"))
        }
        .multilineTextAlignment(.center)
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

struct CommentRow: View {
    let comment: Comment
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            AvatarSlot(url: comment.user.profilePhotoUrl?.asBackendURL, size: 28)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user.username)
                        .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.tail)
                    if comment.user.id == post.user.id {
                        // Recipe author replies get a mint chip so readers
                        // know it's the cook answering.
                        Text("COOK")
                            .scaledFont(10, weight: .bold, relativeTo: .caption2)
                            .foregroundStyle(Theme.primaryInk)
                            .tracking(1.2)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule(style: .continuous).fill(Theme.mintTint))
                    }
                    Spacer(minLength: 0)
                    Text(comment.insertedAt.timeAgo())
                        .scaledFont(12, relativeTo: .caption)
                        .foregroundStyle(Theme.muted)
                        .lineLimit(1)
                }
                Text(comment.body)
                    .scaledFont(14.5, relativeTo: .subheadline)
                    .foregroundStyle(Theme.text)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, HomeMetrics.inset)
    }
}
