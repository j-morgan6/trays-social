import SwiftUI

// W245: preview galleries for the My Tray artboard: full (Plus active), new
// user (Plus locked), a legacy photo post, loading and the error state; plus
// the planner card on its own, a collection and an empty collection. Light,
// dark and largest text.

private struct MyTrayPreviewScreen: View {
    var subtitle: String?
    var planMode: PlannerEntryMode = .open
    var days: [PlanWeekCard.Day] = MyTrayPreviewScreen.week
    var collections: [RecipeCollection] = PreviewData.collections
    var sections: [TraySections.Section]
    var state: ContentLoadState = .content
    @State private var selection = 0

    static let week: [PlanWeekCard.Day] = [
        .init(id: "1", label: "Today", isToday: true, title: "Sesame chicken thighs"),
        .init(id: "2", label: "Fri", isToday: false, title: "Weeknight dal"),
        .init(id: "3", label: "Sat", isToday: false),
        .init(id: "4", label: "Sun", isToday: false, title: "Harissa chickpea stew"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    MyTrayHeader(subtitle: subtitle)
                    PlanWeekCard(mode: planMode, days: days, onOpen: {})
                        .padding(.horizontal, HomeMetrics.inset)
                        .padding(.top, 20)
                    HomeSectionHeading(label: "Collections")
                    CollectionShelf(
                        collections: collections,
                        isPlus: true,
                        onNewCollection: {},
                        onRename: { _ in },
                        onRenameLocked: {},
                        onDelete: { _ in }
                    )
                    MyTrayLists(
                        sections: sections,
                        selection: $selection,
                        state: state,
                        onCreateRecipe: {},
                        onOpenSearch: {},
                        onRetry: {},
                        cell: { post, list in
                            RecipeCard(
                                title: RecipeTitle.from(caption: post.caption),
                                photoURL: nil,
                                authorName: list == 0 ? "You" : post.user.username,
                                context: list == 0 ? post.insertedAt.timeAgo() : nil,
                                cookTime: CookTime.label(minutes: post.cookingTimeMinutes),
                                kind: PostRecipeCard.kind(for: post, recipeFirst: true)
                            )
                        }
                    )
                }
                .padding(.vertical, 24)
            }
            .background(Theme.background)
        }
    }
}

private func sections(own: [Post], saved: [Post]) -> [TraySections.Section] {
    [.init(title: "My recipes", posts: own), .init(title: "Saved", posts: saved)]
}

private func full() -> some View {
    MyTrayPreviewScreen(
        subtitle: MyTrayCopy.headerSubtitle(recipes: 3, saved: 2),
        sections: sections(own: PreviewData.ownRecipes, saved: PreviewData.saved)
    )
}

private func newUser() -> some View {
    MyTrayPreviewScreen(
        subtitle: MyTrayCopy.headerSubtitle(recipes: 0, saved: 0),
        planMode: .gated,
        days: [],
        collections: [],
        sections: sections(own: [], saved: []),
        state: .empty
    )
}

private func legacyPhoto() -> some View {
    MyTrayPreviewScreen(
        subtitle: MyTrayCopy.headerSubtitle(recipes: 4, saved: 2),
        sections: sections(own: PreviewData.ownRecipes + [PreviewData.legacyPhoto], saved: PreviewData.saved)
    )
}

private func loading() -> some View {
    MyTrayPreviewScreen(sections: sections(own: [], saved: []), state: .loading)
}

private func failed() -> some View {
    MyTrayPreviewScreen(sections: sections(own: [], saved: []), state: .error)
}

private func collectionDetail(posts: [Post]) -> some View {
    NavigationStack {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                CollectionDetailHeader(name: "Weeknights", subtitle: MyTrayCopy.collectionSubtitle(count: posts.count))
                Group {
                    if posts.isEmpty {
                        EmptyStateBlock(
                            title: "Nothing in Weeknights yet",
                            subtitle: "Press and hold a recipe in your tray to add it here.",
                            topPadding: 0
                        )
                    } else {
                        LazyVGrid(columns: PostGrid.columns, alignment: .leading, spacing: PostGrid.spacing) {
                            ForEach(posts) { post in PostRecipeCard(post: post) }
                        }
                        .padding(.horizontal, HomeMetrics.inset)
                    }
                }
                .padding(.top, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Theme.background)
    }
}

#Preview("My Tray full · light") { full() }
#Preview("My Tray full · dark") { full().preferredColorScheme(.dark) }
#Preview("My Tray full · largest text") { full().dynamicTypeSize(.accessibility5) }
#Preview("My Tray new user · light") { newUser() }
#Preview("My Tray new user · dark") { newUser().preferredColorScheme(.dark) }
#Preview("My Tray new user · largest text") { newUser().dynamicTypeSize(.accessibility5) }
#Preview("My Tray legacy photo · light") { legacyPhoto() }
#Preview("My Tray legacy photo · dark") { legacyPhoto().preferredColorScheme(.dark) }
#Preview("My Tray loading · light") { loading() }
#Preview("My Tray error · light") { failed() }
#Preview("My Tray error · dark") { failed().preferredColorScheme(.dark) }
#Preview("Collection · light") { collectionDetail(posts: PreviewData.ownRecipes + PreviewData.saved) }
#Preview("Collection · dark") {
    collectionDetail(posts: PreviewData.ownRecipes + PreviewData.saved).preferredColorScheme(.dark)
}

#Preview("Collection · largest text") {
    collectionDetail(posts: PreviewData.ownRecipes).dynamicTypeSize(.accessibility5)
}

#Preview("Collection empty · light") { collectionDetail(posts: []) }
#Preview("Collection error · light") {
    TrayLoadErrorView(title: "Couldn't load this collection", onRetry: {}).background(Theme.background)
}
