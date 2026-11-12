import SwiftUI

/// "See all" for one grouped-search section: a 2-column grid paged by cursor.
/// Sponsored cards appear only when the server interleaves them (the
/// Everyone group); tray and following pages are plain posts.
///
/// W243: cards are the shared RecipeCard at 4:3 and SponsoredRecipeCard,
/// so cards in a row are the same size.
struct SearchGroupView: View {
    let route: SearchGroupRoute
    @State private var viewModel = SearchGroupViewModel()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                if viewModel.isEmpty {
                    EmptyStateBlock(
                        title: String(localized: "No results yet."),
                        subtitle: String(localized: "Try a different recipe, ingredient, or cook."),
                        topPadding: 56,
                        chrome: .plain
                    )
                } else {
                    SearchRecipeGrid(items: viewModel.items) { item in
                        // Every cell pages, so a trailing ad or unknown
                        // card cannot stall pagination.
                        if item.id == viewModel.items.last?.id {
                            Task { await viewModel.loadMore(route) }
                        }
                    }
                    .padding(.horizontal, HomeMetrics.inset)
                }
                if viewModel.isLoading {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible())], spacing: 12) {
                        ForEach(0 ..< 2, id: \.self) { _ in SkeletonRecipeCard() }
                    }
                    .padding(.horizontal, HomeMetrics.inset)
                    .padding(.top, 12)
                    .skeletonGroup(label: String(localized: "Loading search results"))
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
}
