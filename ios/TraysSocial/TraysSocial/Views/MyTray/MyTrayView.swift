import SwiftUI

/// My Tray (W245 restyle, My Tray artboard): the rounded "My Tray" header and
/// a count line, the Plus "Plan your week" card, the Collections shelf, then a
/// two-way switch between My recipes and Saved (Recipes / Saved posts when
/// recipe-first is off). Each list is a uniform 4:3 grid, so cards in a row
/// are the same size, with its own empty block; the tray as a whole shows a
/// skeleton while loading and an error block when the first load fails.
struct MyTrayView: View {
    var onCreateRecipe: () -> Void = {}
    var onOpenSearch: () -> Void = {}

    @Environment(AppState.self) private var appState
    @State private var viewModel = MyTrayViewModel()
    /// W177. Owned here rather than on AppState so the shelf and the tray-card
    /// context menu share one instance without a per-account teardown to
    /// remember on logout.
    @State private var collectionsVM = CollectionsViewModel()
    // W178. Owned by AppShellView so the pushed planner shares this instance.
    @Environment(MealPlannerViewModel.self) private var plannerVM
    @State private var formMode: CollectionFormMode?
    @State private var pendingDelete: RecipeCollection?
    @State private var selectedList = 0

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                MyTrayHeader(subtitle: headerSubtitle)

                // W209: no Plus surfaces while Plus is hidden.
                if showsPlus {
                    PlanYourWeekRow(viewModel: plannerVM)
                        .padding(.horizontal, HomeMetrics.inset)
                        .padding(.top, 20)
                    HomeSectionHeading(label: String(localized: "Collections"))
                    CollectionShelf(
                        collections: collectionsVM.collections,
                        isPlus: appState.isPlus,
                        onNewCollection: { formMode = .create },
                        onRename: { formMode = .rename($0) },
                        onRenameLocked: { collectionsVM.needsPaywall = true },
                        onDelete: { pendingDelete = $0 }
                    )
                }

                MyTrayLists(
                    sections: sections,
                    selection: $selectedList,
                    state: listState,
                    onCreateRecipe: onCreateRecipe,
                    onOpenSearch: onOpenSearch,
                    onRetry: retry
                ) { post, list in
                    gridCell(post, list: list)
                }
            }
            .padding(.top, 116)
            .padding(.bottom, 128)
        }
        .background(Theme.background)
        .refreshable {
            await viewModel.refresh(currentUsername: appState.currentUser?.username)
            // W209: no gated Plus calls while Plus is hidden.
            if showsPlus {
                await collectionsVM.refresh()
                // W178: the user's manual retry when the probe below failed. My
                // Tray never unmounts, so `.task` will not re-fire on its own.
                await plannerVM.loadIfNeeded()
            }
        }
        .task {
            // D94: previously gated on viewModel.posts.isEmpty so the
            // first cold visit loaded. With the .onReceive bookmark
            // sync below we still need a periodic refresh on tab re-
            // entry to pick up saves that happened before the app
            // launched (no in-flight notification) — load() guards on
            // isLoading so a double-fire is a no-op. D98: pass the
            // current username so the user's own posts are merged in.
            await viewModel.load(currentUsername: appState.currentUser?.username)
        }
        // W178: MUST live on the root, not inside PlanYourWeekRow, which only
        // renders when Plus is visible. W245: the full-screen empty state is
        // gone, but the card still reads `plannerVM.hasAnyEntries` to decide
        // between the open week and the locked teaser.
        // W209: keyed on the flag so the launch fetch turning Plus on loads it.
        .task(id: showsPlus) {
            guard showsPlus else { return }
            await plannerVM.loadIfNeeded()
        }
        .onReceive(NotificationCenter.default.publisher(for: .postUpdated)) { notification in
            if let updated = notification.userInfo?["post"] as? Post {
                #if DEBUG
                    // D99: timestamp the landing-time so the broadcast -> apply
                    // delta can be measured in Console.app.
                    let bookmarked = updated.bookmarkedByCurrentUser == true
                    MyTrayViewModel.debugLog.debug(
                        "applyPostUpdate id=\(updated.id) bookmarked=\(bookmarked) at=\(Date().timeIntervalSince1970)"
                    )
                #endif
                viewModel.applyPostUpdate(updated)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postCreated)) { _ in
            // W170: own posts belong in the tray (D98); refresh on publish.
            Task { await viewModel.refresh(currentUsername: appState.currentUser?.username) }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { notification in
            if let id = notification.userInfo?["postId"] as? Int {
                viewModel.removePost(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postDeleteFailed)) { notification in
            if let id = notification.userInfo?["postId"] as? Int {
                viewModel.restorePost(id: id)
            }
        }
        .modifier(CollectionsSurface(
            viewModel: collectionsVM,
            loadsCollections: showsPlus,
            formMode: $formMode,
            pendingDelete: $pendingDelete
        ))
    }

    private var showsPlus: Bool {
        PlusVisibility.showsPlus(paidTier: FeatureFlags.shared.paidTier)
    }

    private func retry() {
        Task { await viewModel.refresh(currentUsername: appState.currentUser?.username) }
    }

    private var recipeFirst: Bool {
        FeatureFlags.shared.recipeFirst
    }

    private var sections: [TraySections.Section] {
        TraySections.make(
            posts: viewModel.posts,
            currentUserId: appState.currentUser?.id,
            recipeFirst: recipeFirst,
            includeEmpty: true
        )
    }

    private var listState: ContentLoadState {
        ContentLoadState.decide(
            hasContent: !viewModel.posts.isEmpty,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            loadFailed: viewModel.loadFailed
        )
    }

    private var headerSubtitle: String? {
        // The counts name My recipes and Saved; classic sections mean something else.
        guard recipeFirst, listState == .content || listState == .empty else { return nil }
        let counts = sections.map(\.posts.count)
        return MyTrayCopy.headerSubtitle(recipes: counts.first ?? 0, saved: counts.last ?? 0)
    }

    /// My recipes names the cook "You" and shows when it was posted; Saved
    /// (and the classic lists) name the cook.
    private func gridCell(_ post: Post, list: Int) -> some View {
        let isOwnList = recipeFirst && list == 0
        return NavigationLink(value: post) {
            PostRecipeCard(
                post: post,
                authorName: isOwnList ? String(localized: "You") : nil,
                context: isOwnList ? post.insertedAt.timeAgo() : nil
            )
        }
        .buttonStyle(.borderless)
        .modifier(AddToCollectionContextMenu(
            isVisible: showsPlus,
            post: post,
            isPlus: appState.isPlus,
            viewModel: collectionsVM,
            onNewCollection: { formMode = .create }
        ))
    }
}
