import SwiftUI

/// Recipe-first Home: Jump back in, Tonight, Friends' trays, and a finite
/// "New from people you follow" row. See the recipe-first spec, section 3,
/// and the W241 redesign canvas (Main artboard, Home presets).
struct HomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = HomeViewModel()
    var onCreateRecipe: () -> Void = {}
    var onOpenSearch: () -> Void = {}

    var body: some View {
        ScrollView {
            state
                .padding(.top, 116)
                .padding(.bottom, 128)
        }
        .task { await viewModel.load() }
        .refreshable { await viewModel.load() }
        .onReceive(NotificationCenter.default.publisher(for: .postCreated)) { _ in
            Task { await viewModel.load() }
        }
    }

    @ViewBuilder
    private var state: some View {
        let screen = HomeScreenState.decide(
            hasPayload: viewModel.payload != nil,
            loadFailed: viewModel.loadFailed,
            isLoading: viewModel.isLoading
        )
        if screen == .content, let payload = viewModel.payload {
            HomeContentView(
                payload: payload,
                greeting: greeting,
                showsTonight: PlusVisibility.showsPlus(paidTier: FeatureFlags.shared.paidTier),
                actions: actions
            )
        } else if screen == .error {
            // First load failed and there is no Home to fall back on. The
            // failure itself was logged, never toasted (D95).
            HomeErrorView { Task { await viewModel.load() } }
        } else {
            HomeLoadingView()
        }
    }

    private var greeting: HomeGreetingHeader.Greeting {
        .init(
            kicker: HomeGreeting.kicker(now: Date()),
            question: HomeGreeting.question(username: appState.currentUser?.username)
        )
    }

    private var actions: HomeContentView.Actions {
        .init(
            createRecipe: onCreateRecipe,
            openSearch: onOpenSearch,
            openPlanner: { appState.navigationPath.append(MealPlannerRoute()) },
            seeAllFriends: {
                guard let me = appState.currentUser?.username else { return }
                appState.navigationPath.append(FollowListRoute(username: me, mode: .following))
            }
        )
    }
}
