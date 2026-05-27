import SwiftUI

struct PostDetailView: View {
    @Environment(AppState.self) private var appState
    let postId: Int
    @State private var viewModel = PostViewModel()
    @State private var showCookMode = false
    @State private var showReport = false

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading, viewModel.post == nil {
                ScrollView {
                    SkeletonPostDetail()
                        .padding(.bottom, 80)
                }
                .skeletonGroup(label: "Loading recipe")
                .allowsHitTesting(false)
                .transition(.opacity)
            } else if viewModel.post == nil, let error = viewModel.loadError {
                PostUnavailableSurface(
                    error: error,
                    onRetry: {
                        Task {
                            await viewModel.loadPost(id: postId)
                            await viewModel.loadComments(postId: postId)
                        }
                    },
                    onBack: { dismiss() }
                )
            } else if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Hero — photo with overlaid title/eyebrow and
                        // floating back/share/bookmark controls.
                        RecipeHero(
                            post: post,
                            bookmarked: post.bookmarkedByCurrentUser ?? false,
                            onBack: { dismiss() },
                            onShare: { /* TODO: share sheet */ },
                            onBookmark: { viewModel.toggleBookmark() }
                        )

                        // Recipe info (byline + metadata + cook's note +
                        // engagement). Title/eyebrow live in the hero
                        // above, so this block starts at the byline.
                        infoSection(post)

                        if post.isRecipe {
                            RecipeBodySection(post: post)
                        }

                        // Tags
                        if !post.tags.isEmpty {
                            tagsSection(post)
                        }

                        // Comments
                        commentsSection(post)

                        // Spacer for comment input
                        Spacer().frame(height: 80)
                    }
                    .containerRelativeFrame(.horizontal, alignment: .leading)
                }

                // Comment input bar
                commentInputBar(post)

                // Start Cooking button (recipes only)
                if post.isRecipe, !post.cookingSteps.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button {
                                showCookMode = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "flame.fill")
                                    Text("Start cooking")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x2A1C00))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                            .shadow(color: Theme.accent.opacity(0.35), radius: 10, y: 4)
                            .padding(.trailing, 16)
                            .padding(.bottom, 70)
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        // Hide the system nav bar — the floating back/share/bookmark
        // controls on the hero serve that role. Edge-back swipe still
        // works (NavigationStack handles it). iOS 17 API; iOS 18 has
        // `.toolbarVisibility(.hidden, for:)`.
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(edges: .top)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    Button("Report Post", role: .destructive) {
                        showReport = true
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.gray)
                }
            }
        }
        .task {
            await viewModel.loadPost(id: postId)
            await viewModel.loadComments(postId: postId)
        }
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .fullScreenCover(isPresented: $showCookMode) {
            if let post = viewModel.post {
                CookModeView(steps: post.cookingSteps, title: post.caption ?? "Recipe")
            }
        }
        .sheet(isPresented: $showReport) {
            ReportSheetView(targetType: "post", targetId: postId)
        }
    }

    // Photo carousel lives in RecipeHero (Views/Post/RecipeHero.swift).

    // MARK: - Info

    //
    // Editorial layout: optional category eyebrow (from tags), oversized
    // serif recipe title (derived from caption first sentence), byline
    // with avatar + relative date, italic cook's note, metadata strip
    // between hairlines, quiet engagement row.

    private func infoSection(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Title + eyebrow now live in RecipeHero above.
            // Byline
            Button {
                appState.navigationPath.append(post.user.username)
            } label: {
                HStack(spacing: 10) {
                    avatarView(for: post.user)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(post.user.username)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Theme.text)
                        Text(post.insertedAt.timeAgo())
                            .font(.system(size: 12))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    Spacer()
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            // Metadata strip
            if post.isRecipe {
                Divider().background(Color.white.opacity(0.08))

                HStack(alignment: .top, spacing: 24) {
                    if let time = post.cookingTimeMinutes {
                        metadataCell(label: "Time", value: formatCookTime(time))
                    }
                    if let servings = post.servings {
                        metadataCell(label: "Serves", value: "\(servings)")
                    }
                    if !post.ingredients.isEmpty {
                        metadataCell(label: "Ingredients", value: "\(post.ingredients.count)")
                    }
                    Spacer(minLength: 0)
                }

                Divider().background(Color.white.opacity(0.08))
            }

            // Cook's note — italic serif pull quote
            let body = bodyText(for: post)
            if !body.isEmpty {
                Text("\u{201C}\(body)\u{201D}")
                    .font(.serifItalic(17))
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 4)
            }

            // Engagement row
            HStack(spacing: 18) {
                Button { viewModel.toggleLike() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: post.likedByCurrentUser ? "heart.fill" : "heart")
                        Text("\(post.likeCount) helpful")
                    }
                    .foregroundStyle(post.likedByCurrentUser ? Theme.primaryLight : Theme.textSecondary)
                }
                .buttonStyle(.borderless)

                Button { viewModel.toggleBookmark() } label: {
                    HStack(spacing: 5) {
                        Image(systemName: post.bookmarkedByCurrentUser == true ? "bookmark.fill" : "bookmark")
                        Text(post.bookmarkedByCurrentUser == true ? "Saved" : "Save")
                    }
                    .foregroundStyle(post.bookmarkedByCurrentUser == true ? Theme.primaryLight : Theme.textSecondary)
                }
                .buttonStyle(.borderless)

                Spacer()

                Image(systemName: "square.and.arrow.up")
                    .foregroundStyle(Theme.textSecondary)
            }
            .font(.system(size: 13))
            .padding(.top, 8)
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }

    // MARK: - Info helpers

    private func avatarView(for user: PostUser) -> some View {
        Group {
            if let urlString = user.profilePhotoUrl, let url = urlString.asBackendURL {
                AsyncImage(url: url) { image in
                    image.resizable().scaledToFill()
                } placeholder: { Color(.systemGray4) }
                    .frame(width: 36, height: 36)
                    .clipShape(Circle())
            } else {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 36, height: 36)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    private func metadataCell(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundStyle(Theme.textSecondary)
                .tracking(1.5)
            Text(value)
                .font(.serif(18))
                .foregroundStyle(Theme.text)
        }
    }

    private func titleText(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled recipe" : candidate
    }

    private func bodyText(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        let title = titleText(for: post)
        guard raw.count > title.count else { return "" }
        return raw.dropFirst(title.count)
            .trimmingCharacters(in: CharacterSet(charactersIn: " \n\t.!?"))
    }

    private func formatCookTime(_ minutes: Int) -> String {
        let hours = minutes / 60
        let mins = minutes % 60
        if hours == 0 { return "\(mins) min" }
        if mins == 0 { return "\(hours) hr" }
        return "\(hours) hr \(mins) min"
    }

    // Recipe body extracted into RecipeBodySection below so
    // PostDetailView stays within SwiftLint's type_body_length budget.
    // The section is a pure function of Post (no viewModel state).

    // MARK: - Tags

    private func tagsSection(_ post: Post) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(post.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.secondary.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Comments

    private func commentsSection(_ post: Post) -> some View {
        CommentsSection(
            post: post,
            comments: viewModel.comments,
            isLoading: viewModel.isLoadingComments,
            loadAttempted: viewModel.commentsLoadAttempted,
            error: viewModel.commentsError,
            onRetry: {
                Task { await viewModel.loadComments(postId: post.id) }
            }
        )
    }

    // MARK: - Comment Input

    private func commentInputBar(_ post: Post) -> some View {
        VStack {
            Spacer()
            HStack(spacing: 10) {
                TextField("Add a comment...", text: $viewModel.commentText)
                    .textFieldStyle(.plain)
                    .padding(10)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 20))

                if !viewModel.commentText.isEmpty {
                    Button {
                        Task { await viewModel.sendComment(postId: post.id) }
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.title2)
                            .foregroundStyle(Theme.accent)
                    }
                    .disabled(viewModel.isSendingComment)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)
        }
    }
}

// MARK: - Comments section

/// Comments slot ported out of PostDetailView so its loading / error /
/// empty branches don't push the parent struct past SwiftLint's
/// type-body ceiling. Renders an editorial header + one of four
/// branches: skeleton (loading), inline retry (error), italic empty
/// copy (loaded and zero comments), or the existing per-comment list.
///
/// The skeleton uses a short delay before appearing so a fast-cached
/// fetch (50ms or less) doesn't flash skeleton rows — per W115's
/// pitfall on transition feel.
private struct CommentsSection: View {
    let post: Post
    let comments: [Comment]
    let isLoading: Bool
    let loadAttempted: Bool
    let error: Error?
    let onRetry: () -> Void

    @State private var skeletonVisible = false

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            header
                .padding(.horizontal, 20)

            content
        }
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text("Notes")
                .font(.serif(24))
                .foregroundStyle(Theme.text)
            Text("\(comments.count)")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    @ViewBuilder
    private var content: some View {
        if let error, comments.isEmpty {
            errorSurface(error: error)
        } else if isLoading, comments.isEmpty {
            loadingSurface
        } else if loadAttempted, comments.isEmpty {
            emptySurface
        } else {
            ForEach(comments) { comment in
                CommentRow(comment: comment, post: post)
            }
        }
    }

    private var loadingSurface: some View {
        VStack(spacing: 6) {
            ForEach(0 ..< 3, id: \.self) { _ in
                SkeletonListRow()
            }
        }
        .opacity(skeletonVisible ? 1 : 0)
        .skeletonGroup(label: "Loading notes")
        .task {
            // Wait 220ms before showing skeletons — a fast-cached
            // /posts/:id/comments returns in well under 200ms and the
            // brief flash of skeleton would feel worse than no
            // indicator at all.
            try? await Task.sleep(for: .milliseconds(220))
            skeletonVisible = true
        }
    }

    private var emptySurface: some View {
        VStack(spacing: 6) {
            Text("No notes yet.")
                .font(.serifItalic(17))
                .foregroundStyle(Theme.text)
            Text("Be the first to leave one.")
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 22)
    }

    private func errorSurface(error _: Error) -> some View {
        VStack(spacing: 10) {
            Text("Couldn't load notes.")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.text)
            Button(action: onRetry) {
                Label("Retry", systemImage: "arrow.clockwise")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2A1C00))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Retry loading notes")
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
    }
}

private struct CommentRow: View {
    let comment: Comment
    let post: Post

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            commentAvatar
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(comment.user.username)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Theme.text)
                    if comment.user.id == post.user.id {
                        // Recipe author replies get a Mint Whisper chip so
                        // readers know it's the cook answering.
                        Text("COOK")
                            .font(.system(size: 9, weight: .medium, design: .monospaced))
                            .foregroundStyle(Color(hex: 0x2A5430))
                            .tracking(1.2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Theme.secondary.opacity(0.4))
                            .clipShape(Capsule())
                    }
                    Spacer(minLength: 0)
                    Text(comment.insertedAt.timeAgo())
                        .font(.system(size: 11))
                        .foregroundStyle(Theme.textSecondary)
                }
                Text(comment.body)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text.opacity(0.9))
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 20)
    }

    private var commentAvatar: some View {
        Group {
            if let url = comment.user.profilePhotoUrl, let imageURL = url.asBackendURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .id(imageURL)
            } else {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 28, height: 28)
                    .overlay(
                        Text(String(comment.user.username.prefix(1)).uppercased())
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                    )
            }
        }
    }
}

// MARK: - Post unavailable surface

/// Inline failure surface shown when the initial post load throws.
/// Distinguishes between 404 ("post not available") and everything
/// else ("couldn't load — retry"). Pulled out of PostDetailView to
/// keep the struct body under the lint ceiling.
private struct PostUnavailableSurface: View {
    let error: Error
    let onRetry: () -> Void
    let onBack: () -> Void

    private var isNotFound: Bool {
        if case .notFound = error as? APIError { return true }
        return false
    }

    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: isNotFound ? "doc.questionmark" : "exclamationmark.triangle")
                .font(.system(size: 28, weight: .regular))
                .foregroundStyle(Theme.textSecondary)

            VStack(spacing: 6) {
                Text(isNotFound ? "Post not available" : "Couldn't load this post")
                    .font(.serif(20))
                    .foregroundStyle(Theme.text)

                Text(isNotFound
                    ? "It may have been removed or the link is wrong."
                    : "Check your connection and try again.")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            HStack(spacing: 12) {
                if !isNotFound {
                    Button(action: onRetry) {
                        Label("Retry", systemImage: "arrow.clockwise")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2A1C00))
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Theme.accent)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Retry loading this post")
                }

                Button(action: onBack) {
                    Text("Back")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Theme.text)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back to previous screen")
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 30)
    }
}

// MARK: - Flow Layout (for tools)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache _: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            let point = CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y)
            subviews[index].place(at: point, proposal: .unspecified)
        }
    }

    private func layout(subviews: Subviews, proposal: ProposedViewSize) -> (size: CGSize, positions: [CGPoint]) {
        // Pre-measure every subview so we can compute a finite fallback width
        // when SwiftUI calls us during a measurement pass with an unspecified proposal.
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let naturalWidth = sizes.reduce(0) { $0 + $1.width }
            + CGFloat(max(0, sizes.count - 1)) * spacing

        // If the parent proposes a finite width, wrap to fit it.
        // If the proposal is nil/infinite (measurement phase), use the natural
        // single-row width so we NEVER report .infinity back up the view tree.
        let maxWidth: CGFloat = {
            if let proposed = proposal.width, proposed.isFinite {
                return proposed
            }
            return naturalWidth
        }()

        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxRowWidth: CGFloat = 0

        for size in sizes {
            if x + size.width > maxWidth, x > 0 {
                maxRowWidth = max(maxRowWidth, x - spacing)
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
        }
        // Account for the final row.
        maxRowWidth = max(maxRowWidth, x - (sizes.isEmpty ? 0 : spacing))

        // Report the actual content extent, not the proposed width — this prevents
        // the layout from telling its parent "I need infinite width" and forcing
        // the enclosing ScrollView/VStack wider than the viewport.
        return (CGSize(width: maxRowWidth, height: y + rowHeight), positions)
    }
}

// MARK: - Recipe Body

//
// Ingredients as a checkable list with mono quantities; method as
// numbered steps with italic serif primary-green numerals. Extracted
// from PostDetailView so the parent struct stays within SwiftLint's
// type_body_length budget.

struct RecipeBodySection: View {
    let post: Post

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            if !post.ingredients.isEmpty {
                ingredientsList
            }
            if !post.cookingSteps.isEmpty {
                methodList
            }
            if !post.tools.isEmpty {
                toolsList
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var ingredientsList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Ingredients")
                .font(.serif(28))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)

            Divider().background(Color.white.opacity(0.08))

            ForEach(post.ingredients) { ingredient in
                VStack(spacing: 0) {
                    HStack(alignment: .top, spacing: 12) {
                        RoundedRectangle(cornerRadius: 3)
                            .stroke(Theme.textSecondary.opacity(0.5), lineWidth: 1.5)
                            .frame(width: 16, height: 16)
                            .padding(.top, 2)

                        Text(quantityText(for: ingredient))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(Theme.textSecondary)
                            .frame(minWidth: 60, alignment: .leading)

                        Text(ingredient.name)
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(.vertical, 10)

                    Divider().background(Color.white.opacity(0.08))
                }
            }
        }
    }

    private var methodList: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Method")
                .font(.serif(28))
                .foregroundStyle(Theme.text)
                .padding(.bottom, 4)

            ForEach(post.cookingSteps) { step in
                HStack(alignment: .top, spacing: 14) {
                    Text("\(step.position)")
                        .font(.serifItalic(28))
                        .foregroundStyle(Theme.primary)
                        .frame(width: 32, alignment: .leading)

                    Text(step.instruction)
                        .font(.system(size: 15))
                        .foregroundStyle(Theme.text)
                        .lineSpacing(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(.vertical, 12)

                Divider().background(Color.white.opacity(0.08))
            }
        }
    }

    private var toolsList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Tools")
                .font(.serif(24))
                .foregroundStyle(Theme.text)

            FlowLayout(spacing: 8) {
                ForEach(post.tools) { tool in
                    Text(tool.name)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Theme.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.secondary.opacity(0.35))
                        .clipShape(Capsule())
                }
            }
        }
    }

    private func quantityText(for ingredient: Ingredient) -> String {
        [ingredient.quantity, ingredient.unit]
            .compactMap { $0?.isEmpty == false ? $0 : nil }
            .joined(separator: " ")
    }
}
