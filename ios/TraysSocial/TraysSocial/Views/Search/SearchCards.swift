import SwiftUI

/// W243: a Search post as the shared RecipeCard. Every Search grid uses 4:3,
/// so cards in a row are the same size.
struct SearchRecipeCard: View {
    let post: Post
    var rank: Int?

    var body: some View {
        RecipeCard(
            title: RecipeTitle.from(caption: post.caption),
            photoURL: post.primaryPhotoURL?.asBackendURL,
            authorName: post.user.username,
            authorAvatarURL: post.user.profilePhotoUrl?.asBackendURL,
            cookTime: CookTime.label(minutes: post.cookingTimeMinutes),
            badge: rank.map { .rank($0) },
            kind: post.isRecipe ? .recipe : .photoPost
        )
    }
}

/// W243: a two-column grid of feed items (posts and sponsored cards), as in
/// Most saved, Everyone and "See all". `ranks` badges Most saved's top three.
struct SearchRecipeGrid: View {
    let items: [FeedItem]
    var ranks: [Int: Int] = [:]
    /// Called for every cell as it appears, so "See all" can page.
    var onCellAppear: ((FeedItem) -> Void)?

    private let columns = [GridItem(.flexible(), spacing: 12), GridItem(.flexible())]

    var body: some View {
        LazyVGrid(columns: columns, alignment: .leading, spacing: 12) {
            ForEach(items) { item in
                cell(item)
                    .onAppear { onCellAppear?(item) }
            }
        }
    }

    @ViewBuilder
    private func cell(_ item: FeedItem) -> some View {
        switch item {
        case let .post(post):
            NavigationLink(value: post) {
                SearchRecipeCard(post: post, rank: ranks[post.id])
            }
            .buttonStyle(.borderless)
        case let .ad(_, slot):
            SponsoredRecipeCard(slot: slot)
        case .unknown:
            // A real (blank) view rather than EmptyView, so paging onAppear
            // still fires when a newer server sends a tag this build lacks.
            Color.clear.frame(height: 1)
        }
    }
}

/// W243: a Search post as a RowCard (In your tray, From people you follow).
struct SearchRowCard: View {
    let post: Post
    var match: RowCard.Match?
    var uses: String?
    var missing: [String] = []

    var body: some View {
        RowCard(
            title: RecipeTitle.from(caption: post.caption),
            photoURL: post.thumbURL?.asBackendURL ?? post.primaryPhotoURL?.asBackendURL,
            authorName: post.user.username,
            authorAvatarURL: post.user.profilePhotoUrl?.asBackendURL,
            detail: CookTime.label(minutes: post.cookingTimeMinutes),
            match: match,
            uses: uses,
            missing: missing
        )
    }
}

/// W243: a Browse category tile (Components artboard, "Category tile"). The
/// server has no category photos, so the tilted photo is a placeholder slot.
struct CategoryTile: View {
    let category: BrowseCategory
    let index: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topLeading) {
                PhotoSlot(url: nil, cornerRadius: 18)
                    .frame(width: 72, height: 72)
                    .rotationEffect(.degrees(-8))
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .offset(x: 10, y: 10)
                    .accessibilityHidden(true)
                Text(category.displayLabel)
                    .roundedFont(16, weight: .bold, relativeTo: .headline)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.trailing, 72)
                    .padding(14)
            }
            .frame(minHeight: 96)
            .background(fill)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(Text(category.displayLabel))
    }

    private var fill: Color {
        switch CategoryTileFill.at(index) {
        case .cream: Theme.creamOrLift
        case .amber: Theme.accentMuted
        case .mint: Theme.mintTint
        }
    }
}

/// W243: the Cooks panel at the top of one-term results. Each row links to
/// the cook's profile; following happens there, not here.
struct SearchCooksPanel: View {
    let users: [User]

    var body: some View {
        VStack(spacing: 0) {
            ForEach(Array(users.enumerated()), id: \.element.id) { offset, user in
                if offset > 0 {
                    Rectangle()
                        .fill(Theme.hairline)
                        .frame(height: 1)
                        .padding(.leading, 74)
                }
                NavigationLink(value: user.username) { row(user) }
                    .buttonStyle(.borderless)
            }
        }
        .padding(.vertical, 6)
        .cardSurface(cornerRadius: 22)
    }

    private func row(_ user: User) -> some View {
        HStack(spacing: 12) {
            AvatarSlot(url: user.profilePhotoUrl?.asBackendURL, size: 48)
            Text(verbatim: "@\(user.username)")
                .scaledFont(15, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Theme.text)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 60)
        .contentShape(Rectangle())
    }
}
