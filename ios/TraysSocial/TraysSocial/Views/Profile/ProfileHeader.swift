import SwiftUI

/// W245: a cook's tray header (Friend's tray artboard): a cream card with the
/// 96pt avatar, the name (the app has usernames only, so name and handle are
/// both the username), the bio, Recipes / Followers / Following and, on
/// someone else's tray, a full-width Follow button. Saved and collections are
/// never shown here; they stay private to My Tray.
struct ProfileHeader: View {
    let user: User
    let isOwnProfile: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(spacing: 14) {
            AvatarSlot(url: user.profilePhotoUrl?.asBackendURL, size: 96)
            VStack(spacing: 6) {
                // A hidden full-size line reserves the height, so a long name that
                // scales down to fit one line does not shrink the header.
                Text(verbatim: "Ag")
                    .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                    .hidden()
                    .frame(maxWidth: .infinity)
                    .overlay {
                        Text(user.username)
                            .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                            .tracking(-0.64)
                            .foregroundStyle(Theme.text)
                            // One line that scales down, then truncates: usernames have
                            // no break points, so a long one must not grow the header.
                            .lineLimit(1)
                            .minimumScaleFactor(0.5)
                            .truncationMode(.tail)
                    }
                    .accessibilityElement(children: .combine)
                Text(verbatim: "@\(user.username)")
                    .scaledFont(14, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
                    .lineLimit(1)
            }
            .multilineTextAlignment(.center)
            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .scaledFont(15, relativeTo: .body)
                    .lineSpacing(3.5)
                    .foregroundStyle(Theme.text)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 440)
                    .fixedSize(horizontal: false, vertical: true)
            }
            ProfileStats(user: user)
                .padding(.top, 2)
            if !isOwnProfile {
                followButton
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 24)
        .padding(.horizontal, 18)
        .padding(.bottom, 20)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous).fill(Theme.creamOrLift)
        )
    }

    private var isFollowing: Bool {
        user.followedByCurrentUser == true
    }

    private var followButton: some View {
        Button(action: onToggleFollow) {
            Text(isFollowing ? String(localized: "Following") : String(localized: "Follow"))
        }
        .buttonStyle(.follow(isFollowing: isFollowing, fillsWidth: true, minHeight: 48))
        .accessibilityLabel(
            isFollowing
                ? String(localized: "Following @\(user.username)")
                : String(localized: "Follow @\(user.username)")
        )
        .accessibilityAddTraits(isFollowing ? .isSelected : [])
    }
}

/// Recipes, Followers, Following. The two follow counts open their lists.
private struct ProfileStats: View {
    let user: User

    var body: some View {
        HStack(spacing: 28) {
            cell(value: user.postCount ?? 0, label: String(localized: "Recipes"))
            NavigationLink(value: FollowListRoute(username: user.username, mode: .followers)) {
                cell(value: user.followerCount ?? 0, label: String(localized: "Followers"))
            }
            .buttonStyle(.borderless)
            NavigationLink(value: FollowListRoute(username: user.username, mode: .following)) {
                cell(value: user.followingCount ?? 0, label: String(localized: "Following"))
            }
            .buttonStyle(.borderless)
        }
    }

    private func cell(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text(value, format: .number)
                .roundedFont(17, weight: .bold, relativeTo: .headline)
                .foregroundStyle(Theme.text)
            Text(label)
                .scaledFont(12.5, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
        }
        .frame(minWidth: 44, minHeight: 44)
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}

/// W245: a cook's tray below the header: "Recipes · Newest first" over a 4:3
/// grid with no author line (every card is theirs), or an empty block.
struct ProfileRecipes: View {
    let user: User
    let posts: [Post]
    let isOwnProfile: Bool

    var body: some View {
        if posts.isEmpty {
            EmptyStateBlock(
                title: isOwnProfile
                    ? String(localized: "Your first recipe goes here.")
                    : String(localized: "No recipes yet."),
                subtitle: isOwnProfile
                    ? String(localized: "The one you make without looking is a good place to start.")
                    : String(localized: "When @\(user.username) posts a recipe, it shows up here."),
                topPadding: 30,
                chrome: .plain
            )
        } else {
            VStack(alignment: .leading, spacing: 0) {
                HomeSectionHeading(
                    label: String(localized: "Recipes"),
                    aside: String(localized: "Newest first")
                )
                LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
                    ForEach(posts) { post in
                        NavigationLink(value: post) {
                            PostRecipeCard(post: post, context: post.insertedAt.timeAgo(), showsAuthor: false)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }
}
