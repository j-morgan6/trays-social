import SwiftUI

/// Recipe-first Home: Jump back in, Tonight, Friends' trays, and a finite
/// "New from people you follow" row. See the recipe-first spec, section 3.
/// Not reachable from the shell yet; Task 12 wires it in behind the flag.
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    var onCreateRecipe: () -> Void = {}
    var onOpenSearch: () -> Void = {}

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let payload = viewModel.payload {
                    content(payload)
                } else {
                    // No Home yet: loading, or the first load failed. Keep the
                    // skeleton either way (spec section 7); pull to refresh retries.
                    SkeletonFade {
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                            ForEach(0 ..< 6, id: \.self) { _ in SkeletonGridTile() }
                        }
                    }
                    .skeletonGroup(label: String(localized: "Loading home"))
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 116)
            .padding(.bottom, 116)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .postCreated)) { _ in
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private func content(_ payload: HomePayload) -> some View {
        if HomeLayout.showsWelcome(payload) {
            welcome(payload.suggestedCooks)
        }
        if !payload.jumpBackIn.isEmpty {
            jumpBackIn(payload.jumpBackIn)
        }
        if let tonight = payload.tonight {
            tonightStrip(tonight)
        }
        if !payload.friendsTrays.isEmpty {
            friendsTrays(payload.friendsTrays)
        } else if !HomeLayout.showsWelcome(payload), !payload.suggestedCooks.isEmpty {
            cooksRow(payload.suggestedCooks)
        }
        if HomeLayout.showsNewRow(payload) {
            newFromFollowing(payload.newFromFollowing)
        }
    }

    /// Only rendered when the planner has an entry for today; opens the
    /// planner rather than the recipe.
    private func tonightStrip(_ entry: MealPlanEntry) -> some View {
        Button {
            appState.navigationPath.append(MealPlannerRoute())
        } label: {
            HStack {
                Text("Tonight: \(entry.post.title)").font(.system(size: 14, weight: .semibold))
                Spacer()
                Text("Week").font(.system(size: 13)).foregroundStyle(.secondary)
                Image(systemName: "chevron.right").font(.system(size: 12)).foregroundStyle(.secondary)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.surface))
        }
        .buttonStyle(.plain)
    }

    private func jumpBackIn(_ posts: [Post]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "Jump back in"))
            LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible())], spacing: 8) {
                ForEach(posts) { post in
                    NavigationLink(value: post) { JumpBackInTile(post: post) }
                        .buttonStyle(.borderless)
                }
            }
        }
    }

    private func friendsTrays(_ friends: [FriendTray]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "Friends' trays"), onSeeAll: {
                guard let me = appState.currentUser?.username else { return }
                appState.navigationPath.append(FollowListRoute(username: me, mode: .following))
            })
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(friends) { friend in
                        NavigationLink(value: friend.username) {
                            CookAvatar(id: friend.id, username: friend.username, photoURL: friend.profilePhotoUrl)
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func cooksRow(_ cooks: [SuggestedCook]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "Cooks to follow"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(cooks) { cook in
                        NavigationLink(value: cook.username) {
                            CookAvatar(
                                id: cook.id,
                                username: cook.username,
                                photoURL: cook.profilePhotoUrl,
                                caption: String(localized: "\(cook.recipeCount) recipes")
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func newFromFollowing(_ posts: [Post]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(label: String(localized: "New from people you follow"))
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(posts) { post in
                        NavigationLink(value: post) {
                            GridCard(
                                photoKey: HomeTiles.photoKey(post.id),
                                title: RecipeTitle.from(caption: post.caption),
                                url: post.primaryPhotoURL?.asBackendURL
                            )
                            .frame(width: 140)
                        }
                        .buttonStyle(.borderless)
                    }
                    CaughtUpCard(isEmpty: posts.isEmpty)
                }
            }
        }
    }

    private func welcome(_ cooks: [SuggestedCook]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Welcome to Trays").font(.system(size: 24, weight: .bold))
            Button("Post your first recipe", action: onCreateRecipe)
                .buttonStyle(.borderedProminent)
            Button("Find recipes in Search", action: onOpenSearch)
                .buttonStyle(.bordered)
            if !cooks.isEmpty {
                cooksRow(cooks)
            }
        }
    }
}
