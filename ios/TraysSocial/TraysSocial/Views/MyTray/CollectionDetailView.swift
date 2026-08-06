import SwiftUI

/// Route pushed onto `AppState.navigationPath`. Precedent: `FollowListRoute`.
/// Carrying the name means the navigation title is right on the first frame,
/// before the posts request returns.
struct CollectionRoute: Hashable {
    let id: Int
    let name: String
}

/// One collection's recipes: a 2-column grid identical in shape to My Tray's,
/// with cursor pagination and a remove-from-collection context action.
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
                if viewModel.isEmpty, !viewModel.isLoading {
                    EditorialEmptyState(
                        title: String(localized: "Nothing in this collection yet"),
                        subtitle: String(localized: "Add recipes from your tray.")
                    )
                } else {
                    grid
                        .padding(.horizontal, 16)

                    if viewModel.isLoadingMore {
                        ProgressView()
                            .tint(.gray)
                            .frame(maxWidth: .infinity)
                            .padding()
                    }
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 116)
        }
        .background(Theme.background)
        .navigationTitle(route.name)
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if viewModel.isLoading, viewModel.isEmpty {
                SkeletonFade {
                    LazyVGrid(
                        columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                        spacing: 10
                    ) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            SkeletonGridTile()
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .allowsHitTesting(false)
                    .skeletonGroup(label: String(localized: "Loading collection"))
                }
            }
        }
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

    private var grid: some View {
        LazyVGrid(
            columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
            spacing: 10
        ) {
            ForEach(viewModel.posts) { post in
                NavigationLink(value: post) {
                    GridCard(
                        photoKey: photoKey(for: post),
                        title: gridTitle(for: post),
                        url: post.primaryPhotoURL?.asBackendURL
                    )
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

    private func photoKey(for post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    private func gridTitle(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return String(localized: "Untitled") }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? String(localized: "Untitled") : candidate
    }
}
