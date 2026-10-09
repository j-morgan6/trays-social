import SwiftUI

/// Replaces `MainView` as the user-visible nav shell once W129 wires it
/// in. Hosts a `TabView(.page)` of Feed / My Tray / Find — or Home /
/// My Tray / Search when `FeatureFlags.recipeFirst` is on (W195) — under
/// two floating pills (`TopPill` + `BottomPill`) overlaid via `ZStack`.
///
/// Pill visibility is owned by `ShellViewModel.pillsHidden`. When that
/// flag flips, the pills transition off-screen via `.move(edge:)`
/// combined with `.opacity` — or, when Reduce Motion is on, they
/// simply cross-fade.
///
/// All existing navigation destinations (Post, String/username,
/// NotificationRoute, FollowListRoute) and the CreatePostView sheet
/// from `MainView` are preserved verbatim. `ShellViewModel` is placed
/// in the environment so deeper screens (Cook Mode in particular) can
/// hide the pills without threading callbacks back up.
struct AppShellView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var shell = ShellViewModel()
    // W178. Owned by the shell, not by MyTrayView: the planner is a root-stack
    // destination, so My Tray's @State is not reachable from it. One instance
    // means the tray's entry row and the planner screen share a loaded week.
    @State private var planner = MealPlannerViewModel()
    @State private var showCreatePost = false
    // W195: the opening tab is applied once per mount, never on re-render.
    @State private var didApplyInitialTab = false
    // W195: only a real return from the background refreshes the flags, not
    // launch or an inactive blip (Control Center, notification shade).
    @State private var wasBackgrounded = false

    var body: some View {
        @Bindable var state = appState
        let layout = ShellLayout.decide(recipeFirst: FeatureFlags.shared.recipeFirst)

        NavigationStack(path: $state.navigationPath) {
            ZStack(alignment: .top) {
                TabView(selection: $state.selectedTray) {
                    leadingPage(for: layout)
                    // Outside the layout switch so My Tray keeps its identity
                    // (and its loaded state) when the flag flips mid-session.
                    MyTrayView()
                        .tag(AppState.TrayTab.myTray)
                    trailingPage(for: layout)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 0) {
                    if !shell.pillsHidden {
                        TopPill(
                            selectedTray: $state.selectedTray,
                            layout: layout,
                            hasUnread: appState.unreadNotificationCount > 0,
                            unreadCount: appState.unreadNotificationCount,
                            onBellTap: {
                                state.navigationPath.append(NotificationRoute())
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.top, 8)
                        .transition(pillTransition(edge: .top))
                    }

                    Spacer(minLength: 0)

                    if !shell.pillsHidden {
                        BottomPill(
                            profilePhotoURL: appState.currentUser?.profilePhotoUrl,
                            onCreateTap: { showCreatePost = true },
                            onProfileTap: {
                                state.navigationPath.append(appState.currentUser?.username ?? "")
                            }
                        )
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                        .transition(pillTransition(edge: .bottom))
                    }
                }
            }
            .background(Theme.background)
            .navigationDestination(for: Post.self) { post in
                // D77: pass the full Post (loaded by the feed/profile/find list)
                // through so PostDetailView can render instantly while it
                // refreshes /posts/:id in the background. Deep-link stubs
                // come in with only the id populated — the optional
                // initialPost is a no-op in that case.
                PostDetailView(postId: post.id, initialPost: post.user.id == 0 ? nil : post)
            }
            .navigationDestination(for: String.self) { username in
                ProfileView(username: username)
            }
            .navigationDestination(for: NotificationRoute.self) { _ in
                NotificationsView()
            }
            .navigationDestination(for: FollowListRoute.self) { route in
                FollowListView(route: route)
            }
            .navigationDestination(for: CollectionRoute.self) { route in
                CollectionDetailView(route: route)
            }
            .navigationDestination(for: MealPlannerRoute.self) { _ in
                MealPlannerView()
            }
            .navigationDestination(for: SearchGroupRoute.self) { route in
                SearchGroupView(route: route)
            }
            .sheet(isPresented: $showCreatePost) {
                CreatePostView()
            }
        }
        .tint(Theme.primary)
        .environment(shell)
        // Outside the NavigationStack, like `shell`, so pushed destinations
        // (MealPlannerView) can read it too.
        .environment(planner)
        .task {
            // D72: refresh the bell's amber-dot signal on shell mount
            // so the user sees the right state before they open
            // Notifications. NotificationsView keeps it fresh after
            // that via its own .task + onChange.
            await appState.refreshUnreadNotificationsCount()

            // W169: the shell only mounts for authenticated users, so this
            // is the contextual post-login moment to prompt for push
            // permission (first run) or silently re-register a possibly
            // rotated token / rebind it to a newly logged-in account.
            PushNotificationService.syncRegistration()

            // W175: same "contextually after login" reasoning as push. The
            // *listener* attaches at launch (renewals are delivered once), but
            // the *drain* has to be here — it needs a bearer to bind an
            // entitlement to an account. This is what picks up a purchase made
            // while signed out, after a reinstall, or on a second device.
            // Read path: failures log, never toast (D95).
            await SubscriptionService.shared.syncCurrentEntitlements()
        }
        // W195: a separate .task so the launch calls above don't wait on the
        // /features round trip. Paging TabView pages don't re-run .task, so
        // the shell owns the refresh. Read path: failures log only (D95).
        .task {
            let before = ShellLayout.decide(recipeFirst: FeatureFlags.shared.recipeFirst)
            await FeatureFlags.shared.refresh()
            let after = ShellLayout.decide(recipeFirst: FeatureFlags.shared.recipeFirst)
            let tab = after.tabAfterLaunchFetch(from: before, current: appState.selectedTray)
            if tab != appState.selectedTray {
                appState.selectedTray = tab
            }
        }
        .onAppear {
            guard !didApplyInitialTab else { return }
            didApplyInitialTab = true
            // Classic keeps today's behaviour: AppState already opens on My Tray,
            // and a re-mount in the same process keeps the last tab.
            let launchLayout = ShellLayout.decide(recipeFirst: FeatureFlags.shared.recipeFirst)
            if launchLayout == .recipeFirst {
                appState.selectedTray = launchLayout.initialTab
            }
        }
        .onChange(of: FeatureFlags.shared.recipeFirst) { _, recipeFirst in
            let newLayout = ShellLayout.decide(recipeFirst: recipeFirst)
            appState.selectedTray = newLayout.normalize(appState.selectedTray)
        }
        .onChange(of: scenePhase) { _, phase in
            switch phase {
            case .background:
                wasBackgrounded = true
            case .active where wasBackgrounded:
                wasBackgrounded = false
                Task { await FeatureFlags.shared.refresh() }
            default:
                break
            }
        }
    }

    @ViewBuilder
    private func leadingPage(for layout: ShellLayout) -> some View {
        switch layout {
        case .classic:
            FeedView()
                .tag(AppState.TrayTab.feed)
        case .recipeFirst:
            HomeView(
                onCreateRecipe: { showCreatePost = true },
                onOpenSearch: { appState.selectedTray = .search }
            )
            .tag(AppState.TrayTab.home)
        }
    }

    @ViewBuilder
    private func trailingPage(for layout: ShellLayout) -> some View {
        switch layout {
        case .classic:
            FindView()
                .tag(AppState.TrayTab.find)
        case .recipeFirst:
            SearchView()
                .tag(AppState.TrayTab.search)
        }
    }

    private func pillTransition(edge: Edge) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .move(edge: edge).combined(with: .opacity)
    }
}
