import SwiftUI

/// W245: My Tray's header (My Tray artboard): the rounded title and a count
/// line ("7 recipes · 8 saved", or the new-user line).
struct MyTrayHeader: View {
    var subtitle: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("My Tray")
                .roundedFont(32, weight: .heavy, relativeTo: .largeTitle)
                .tracking(-0.64)
                .foregroundStyle(Theme.text)
            if let subtitle {
                Text(subtitle)
                    .scaledFont(15, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.top, 6)
        .padding(.horizontal, HomeMetrics.inset)
    }
}

/// W245: the two lists behind the switch (My recipes / Saved, or Recipes /
/// Saved posts when recipe-first is off). Shows the selected list as a 4:3
/// grid, its own empty block, the skeleton while the tray loads, or the error
/// block. `cell` lets the caller attach its context menu to each card.
struct MyTrayLists<Cell: View>: View {
    let sections: [TraySections.Section]
    @Binding var selection: Int
    let state: ContentLoadState
    let onCreateRecipe: () -> Void
    let onOpenSearch: () -> Void
    let onRetry: () -> Void
    @ViewBuilder let cell: (Post, Int) -> Cell

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SegmentedPills(options: options, selection: $selection)
                .padding(.horizontal, HomeMetrics.inset)
                .padding(.top, 30)
                .padding(.bottom, 16)
            list
        }
    }

    private var options: [SegmentedPills<Int>.Option] {
        sections.enumerated().map { index, section in
            .init(value: index, title: section.title, count: state == .loading ? nil : section.posts.count)
        }
    }

    private var selectedPosts: [Post] {
        sections.indices.contains(selection) ? sections[selection].posts : []
    }

    @ViewBuilder
    private var list: some View {
        switch state {
        case .loading:
            MyTrayListSkeleton()
        case .error:
            TrayLoadErrorView(title: String(localized: "Couldn't load your tray"), onRetry: onRetry)
        case .empty, .content:
            if selectedPosts.isEmpty {
                emptyBlock
            } else {
                LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
                    ForEach(selectedPosts) { post in
                        cell(post, selection)
                    }
                }
                .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }

    /// The first list is the cook's own recipes (classic: every recipe); the
    /// second is what they saved.
    @ViewBuilder
    private var emptyBlock: some View {
        if selection == 0 {
            EmptyStateBlock(
                title: String(localized: "Your first recipe goes here."),
                subtitle: String(localized: "The one you make without looking is a good place to start."),
                topPadding: 0,
                action: .init(
                    title: String(localized: "Post a recipe"),
                    systemImage: "plus",
                    isPrimary: true,
                    perform: onCreateRecipe
                )
            )
        } else {
            EmptyStateBlock(
                title: String(localized: "Nothing saved yet."),
                subtitle: String(localized: "Save a recipe from Search or a friend's tray and it waits here."),
                topPadding: 0,
                action: .init(
                    title: String(localized: "Find recipes in Search"),
                    systemImage: "magnifyingglass",
                    perform: onOpenSearch
                )
            )
        }
    }
}
