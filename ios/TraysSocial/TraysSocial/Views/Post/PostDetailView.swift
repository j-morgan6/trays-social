import SwiftUI

struct PostDetailView: View {
    let postId: Int
    @State private var viewModel = PostViewModel()
    @State private var showCookMode = false

    var body: some View {
        ZStack(alignment: .bottom) {
            if viewModel.isLoading {
                ProgressView().tint(Theme.accent)
            } else if let post = viewModel.post {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // Photo carousel
                        photoSection(post)

                        // Recipe info
                        infoSection(post)

                        if post.isRecipe {
                            recipeBody(post)
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
                if post.isRecipe && !post.cookingSteps.isEmpty {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Button("Start Cooking") {
                                showCookMode = true
                            }
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                            .background(Theme.primary)
                            .clipShape(Capsule())
                            .shadow(color: Theme.primary.opacity(0.3), radius: 8, y: 4)
                            .padding(.trailing, 16)
                            .padding(.bottom, 70)
                        }
                    }
                }
            }
        }
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadPost(id: postId)
            await viewModel.loadComments(postId: postId)
        }
        .fullScreenCover(isPresented: $showCookMode) {
            if let post = viewModel.post {
                CookModeView(steps: post.cookingSteps, title: post.caption ?? "Recipe")
            }
        }
    }

    // MARK: - Photo

    @ViewBuilder
    private func photoSection(_ post: Post) -> some View {
        if post.photos.count > 1 {
            TabView {
                ForEach(post.photos.sorted(by: { $0.position < $1.position }), id: \.position) { photo in
                    AsyncImage(url: photo.url.asBackendURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Rectangle().fill(Color(.systemGray5))
                    }
                    .containerRelativeFrame(.horizontal)
                    .frame(height: 300)
                    .clipped()
                }
            }
            .tabViewStyle(.page)
            .frame(height: 300)
        } else if let url = post.primaryPhotoURL {
            AsyncImage(url: url.asBackendURL) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle().fill(Color(.systemGray5))
            }
            .containerRelativeFrame(.horizontal)
            .frame(height: 300)
            .clipped()
        }
    }

    // MARK: - Info

    private func infoSection(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let caption = post.caption {
                Text(caption)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(Theme.text)
            }

            HStack {
                Circle().fill(Color(.systemGray4)).frame(width: 24, height: 24)
                Text(post.user.username)
                    .font(.subheadline)
                    .foregroundStyle(.gray)

                Spacer()

                // Actions
                HStack(spacing: 16) {
                    Button { viewModel.toggleLike() } label: {
                        Label("\(post.likeCount)", systemImage: post.likedByCurrentUser ? "heart.fill" : "heart")
                            .foregroundStyle(post.likedByCurrentUser ? .red : .gray)
                    }

                    Button { viewModel.toggleBookmark() } label: {
                        Image(systemName: post.bookmarkedByCurrentUser == true ? "bookmark.fill" : "bookmark")
                            .foregroundStyle(post.bookmarkedByCurrentUser == true ? .orange : .gray)
                    }
                }
                .font(.subheadline)
            }

            if post.isRecipe {
                HStack(spacing: 16) {
                    if let time = post.cookingTimeMinutes {
                        Label("\(time) min", systemImage: "clock")
                    }
                    if let servings = post.servings {
                        Label("\(servings) servings", systemImage: "person.2")
                    }
                    Label("\(post.commentCount)", systemImage: "bubble.right")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
        }
        .padding(16)
    }

    // MARK: - Recipe Body

    private func recipeBody(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            if !post.ingredients.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Ingredients")
                        .font(.headline)
                        .foregroundStyle(Theme.text)

                    ForEach(post.ingredients) { ingredient in
                        HStack {
                            Text(ingredient.name)
                                .foregroundStyle(Theme.text)
                            Spacer()
                            Text([ingredient.quantity, ingredient.unit].compactMap { $0 }.joined(separator: " "))
                                .foregroundStyle(.secondary)
                        }
                        .font(.subheadline)
                    }
                }
            }

            if !post.cookingSteps.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Steps")
                        .font(.headline)
                        .foregroundStyle(Theme.text)

                    ForEach(post.cookingSteps) { step in
                        HStack(alignment: .top, spacing: 12) {
                            Text("\(step.position)")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 24, height: 24)
                                .background(Theme.accent.opacity(0.15))
                                .clipShape(Circle())

                            Text(step.instruction)
                                .font(.subheadline)
                                .foregroundStyle(Theme.text)
                        }
                    }
                }
            }

            if !post.tools.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Tools")
                        .font(.headline)
                        .foregroundStyle(Theme.text)

                    FlowLayout(spacing: 8) {
                        ForEach(post.tools) { tool in
                            Text(tool.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(Theme.surface)
                                .clipShape(Capsule())
                        }
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Tags

    private func tagsSection(_ post: Post) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(post.tags, id: \.self) { tag in
                    Text("#\(tag)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Theme.surface)
                        .clipShape(Capsule())
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Comments

    private func commentsSection(_ post: Post) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Comments (\(viewModel.comments.count))")
                .font(.headline)
                .foregroundStyle(Theme.text)
                .padding(.horizontal, 16)

            ForEach(viewModel.comments) { comment in
                HStack(alignment: .top, spacing: 10) {
                    Circle().fill(Color(.systemGray4)).frame(width: 28, height: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text(comment.user.username)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(Theme.text)
                            Text(comment.insertedAt.timeAgo())
                                .font(.caption2)
                                .foregroundStyle(.tertiary)
                        }
                        Text(comment.body)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.horizontal, 16)
            }
        }
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
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

// MARK: - Flow Layout (for tools)

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = layout(subviews: subviews, proposal: proposal)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = layout(subviews: subviews, proposal: proposal)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
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
            if x + size.width > maxWidth && x > 0 {
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

