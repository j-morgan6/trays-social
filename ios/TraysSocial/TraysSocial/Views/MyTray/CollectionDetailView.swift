import SwiftUI

/// Route pushed onto `AppState.navigationPath`. Precedent: `FollowListRoute`.
/// Carrying the name means the navigation title is right on the first frame,
/// before the posts request returns.
struct CollectionRoute: Hashable {
    let id: Int
    let name: String
}

/// One collection's recipes (W245 restyle, collection artboard): the name as
/// an in-page rounded title, a count line, then a uniform 4:3 grid with cursor
/// pagination and a remove-from-collection context action. A failed load
/// shows the error block (logged only, never toasted).
///
/// No ads, sponsored cards, or discovery inserts appear here — My Tray and
/// everything reachable from it stays pristine per the monetization spec.
struct CollectionDetailView: View {
    let route: CollectionRoute

    @State private var viewModel: CollectionDetailViewModel

    init(route: CollectionRoute) {
        self.route = route
        _viewModel = State(initialValue: CollectionDetailViewModel(collectionID: route.id))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CollectionDetailHeader(
                    name: route.name,
                    subtitle: MyTrayCopy.collectionSubtitle(count: viewModel.hasMore ? nil : viewModel.posts.count)
                )
                content
                    .padding(.top, 20)
            }
            .padding(.top, 16)
            .padding(.bottom, 60)
        }
        .background(Theme.background)
        // The name is the in-page title; an empty inline title avoids
        // showing it twice.
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .animation(.easeInOut(duration: 0.18), value: viewModel.isLoading)
        .task { await viewModel.load() }
        .refreshable { await viewModel.refresh() }
        .onReceive(NotificationCenter.default.publisher(for: .postUpdated)) { notification in
            if let updated = notification.userInfo?["post"] as? Post {
                viewModel.applyPostUpdate(updated)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .postDeleted)) { notification in
            if let id = notification.userInfo?["postId"] as? Int {
                viewModel.removePost(id: id)
            }
        }
    }

    private var state: ContentLoadState {
        ContentLoadState.decide(
            hasContent: !viewModel.posts.isEmpty,
            hasLoaded: viewModel.hasLoaded,
            isLoading: viewModel.isLoading,
            loadFailed: viewModel.loadFailed
        )
    }

    @ViewBuilder
    private var content: some View {
        switch state {
        case .loading:
            MyTrayListSkeleton()
        case .error:
            let copy = CollectionLoadErrorCopy.decide(notFound: viewModel.notFound)
            TrayLoadErrorView(
                title: copy.title,
                subtitle: copy.subtitle,
                onRetry: copy.allowsRetry ? { Task { await viewModel.refresh() } } : nil
            )
        case .empty:
            EmptyStateBlock(
                title: String(localized: "Nothing in \(route.name) yet"),
                subtitle: String(localized: "Press and hold a recipe in your tray to add it here."),
                topPadding: 0
            )
        case .content:
            grid
                .padding(.horizontal, HomeMetrics.inset)
            if viewModel.isLoadingMore {
                ProgressView()
                    .tint(Theme.muted)
                    .frame(maxWidth: .infinity)
                    .padding()
            }
        }
    }

    private var grid: some View {
        LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
            ForEach(viewModel.posts) { post in
                NavigationLink(value: post) {
                    PostRecipeCard(post: post)
                }
                .buttonStyle(.borderless)
                .contextMenu {
                    // Removing is never gated — a lapsed subscriber keeps full
                    // control of what they already organized.
                    Button(role: .destructive) {
                        viewModel.removePost(post)
                    } label: {
                        Label(
                            String(localized: "Remove from collection"),
                            systemImage: "minus.circle"
                        )
                    }
                }
                .onAppear {
                    if post.id == viewModel.posts.last?.id {
                        Task { await viewModel.loadMore() }
                    }
                }
            }
        }
    }
}

/// W245: a collection's in-page title and its count / privacy line.
struct CollectionDetailHeader: View {
    let name: String
    let subtitle: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(name)
                .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                .tracking(-0.64)
                .foregroundStyle(Theme.text)
                .lineLimit(3)
            Text(subtitle)
                .scaledFont(15, relativeTo: .subheadline)
                .foregroundStyle(Theme.muted)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, HomeMetrics.inset)
    }
}
