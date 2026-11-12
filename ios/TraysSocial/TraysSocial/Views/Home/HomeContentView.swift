import SwiftUI

/// W241: the loaded Home, laid out per the redesign canvas. Takes plain
/// values and closures (no AppState) so it can be previewed. Every card and
/// row sets its own text colour, because `.borderless` NavigationLinks tint
/// their labels.
struct HomeContentView: View {
    struct Actions {
        var createRecipe: () -> Void = {}
        var openSearch: () -> Void = {}
        var openPlanner: () -> Void = {}
        var seeAllFriends: () -> Void = {}
    }

    let payload: HomePayload
    let greeting: HomeGreetingHeader.Greeting
    var showsTonight = true
    var actions = Actions()
    var now = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if HomeLayout.showsWelcome(payload) {
                HomeWelcomeBlock(
                    cooks: payload.suggestedCooks,
                    onCreateRecipe: actions.createRecipe,
                    onOpenSearch: actions.openSearch
                )
            } else {
                HomeGreetingHeader(greeting: greeting)
            }
            if !payload.jumpBackIn.isEmpty {
                jumpBackIn(payload.jumpBackIn)
            }
            // W209: the strip opens the Plus planner, so it hides with Plus.
            if showsTonight, let tonight = payload.tonight {
                HomeTonightStrip(entry: tonight, action: actions.openPlanner)
                    .padding(.horizontal, HomeMetrics.inset)
                    .padding(.top, 20)
            }
            if !payload.friendsTrays.isEmpty {
                friendsTrays(payload.friendsTrays)
            } else if !HomeLayout.showsWelcome(payload), !payload.suggestedCooks.isEmpty {
                HomeSectionHeading(label: String(localized: "Cooks to follow"))
                HomeCooksCard(cooks: payload.suggestedCooks)
                    .padding(.horizontal, HomeMetrics.inset)
            }
            if HomeLayout.showsNewRow(payload) {
                newFromFollowing(payload.newFromFollowing)
            }
        }
    }

    private func jumpBackIn(_ posts: [Post]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeading(label: String(localized: "Jump back in"))
            LazyVGrid(
                columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())],
                alignment: .leading,
                spacing: 12
            ) {
                ForEach(posts) { post in
                    NavigationLink(value: post) {
                        HomeRecipeCard(post: post, aspectRatio: 4.0 / 3.0)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, HomeMetrics.inset)
        }
    }

    private func friendsTrays(_ friends: [FriendTray]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HomeSectionHeading(label: String(localized: "Friends' trays"), onSeeAll: actions.seeAllFriends)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(friends) { friend in
                        NavigationLink(value: friend.username) {
                            HomeFriendAvatar(username: friend.username, photoURL: friend.profilePhotoUrl?.asBackendURL)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }

    @ViewBuilder
    private func newFromFollowing(_ posts: [Post]) -> some View {
        HomeSectionHeading(label: String(localized: "New from people you follow"))
        if posts.isEmpty {
            EndCard(
                title: String(localized: "Nothing new this week"),
                message: String(localized: "When someone you follow posts a recipe, it shows up here for seven days.")
            )
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, HomeMetrics.inset)
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(posts) { post in
                        NavigationLink(value: post) {
                            HomeRecipeCard(
                                post: post,
                                aspectRatio: 4.0 / 5.0,
                                context: post.insertedAt.timeAgo(),
                                isNew: RecipeFreshness.isNew(insertedAt: post.insertedAt, now: now)
                            )
                            .frame(width: HomeMetrics.rowCardWidth)
                        }
                        .buttonStyle(.borderless)
                    }
                    EndCard(
                        title: String(localized: "You're caught up"),
                        message: String(localized: "That's everything from the last 7 days. Time to cook.")
                    )
                    .frame(width: HomeMetrics.rowCardWidth)
                    .frame(maxHeight: .infinity)
                }
                // Equal heights: the end card stretches to the tallest card.
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }
}

enum HomeMetrics {
    /// Canvas content inset; horizontal rows bleed past it to the screen edge.
    static let inset: CGFloat = 18
    static let rowCardWidth: CGFloat = 176
}
