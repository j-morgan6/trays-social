import SwiftUI

/// "See all" for one grouped-search section: a 2-column grid paged by cursor.
/// Sponsored tiles appear only when the server interleaves them (the
/// Everyone group); tray and following pages are plain posts.
struct SearchGroupView: View {
    let route: SearchGroupRoute
    @State private var viewModel = SearchGroupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isEmpty {
                    EditorialEmptyState(title: String(localized: "No results yet."))
                } else {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(viewModel.items) { item in
                            cell(item)
                                .onAppear {
                                    // Every cell pages, so a trailing ad or
                                    // unknown tile cannot stall pagination.
                                    if item.id == viewModel.items.last?.id {
                                        Task { await viewModel.loadMore(route) }
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.gray)
                        .frame(maxWidth: .infinity)
                        .padding()
                }
            }
            .padding(.top, 16)
            .padding(.bottom, 116)
        }
        .background(Theme.background)
        .navigationTitle(route.group.title)
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.loadInitial(route) }
    }

    @ViewBuilder
    private func cell(_ item: FeedItem) -> some View {
        switch item {
        case let .post(post):
            NavigationLink(value: post) {
                GridCard(
                    photoKey: HomeTiles.photoKey(post.id),
                    title: RecipeTitle.from(caption: post.caption),
                    url: post.primaryPhotoURL?.asBackendURL
                )
            }
            .buttonStyle(.borderless)
        case let .ad(_, slot):
            SponsoredTileView(slot: slot)
        case .unknown:
            // A real (blank) view rather than EmptyView, so the paging
            // onAppear still fires when a newer server ends a page with a
            // tag this build does not know.
            Color.clear.frame(height: 1)
        }
    }
}
