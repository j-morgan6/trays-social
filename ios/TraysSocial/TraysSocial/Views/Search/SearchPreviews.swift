import SwiftUI

// W243: preview galleries for the Search states on the Main artboard:
// a browse, b one term, c ingredients, d no matches, e loading. Light, dark
// and largest text. Photos and avatars are nil, so the cream placeholders
// show.

private enum SearchPreviewData {
    private static func post(_ id: Int, _ caption: String, minutes: Int, cook: String) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "\(caption)", "cooking_time_minutes": \(minutes),
         "servings": 2, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-11-10T18:00:00Z",
         "user": {"id": \(id + 100), "username": "\(cook)", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    private static func item(_ json: String) -> String {
        #"{"type": "post", "post": \#(json)}"#
    }

    private static let ad = #"{"type": "ad", "ad": {"slot": 0, "placement": "find"}}"#

    private static let recipes = [
        post(1, "Garlic chicken and crispy rice", minutes: 35, cook: "lucia"),
        post(2, "Ginger chicken rice bowls with a very long title that wraps twice", minutes: 30, cook: "noor"),
        post(3, "Peanut noodles", minutes: 20, cook: "sam"),
        post(4, "Lemon herb roast chicken", minutes: 90, cook: "maya"),
        post(5, "Weeknight dal", minutes: 40, cook: "jonah"),
    ]

    private static func decode<T: Decodable & Sendable>(_ json: String) -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        // Fixed sample data; a decode failure here is a preview authoring bug.
        // swiftlint:disable:next force_try
        return try! decoder.decode(DataResponse<T>.self, from: Data(json.utf8)).data
    }

    static var browse: BrowsePayload {
        let categories = ["quick_dinners", "chicken", "pasta", "breakfast", "baking", "soups"]
            .map { #"{"key": "\#($0)", "label": "\#($0)"}"# }
            .joined(separator: ",")
        let mostSaved = (recipes.prefix(4).map(item) + [ad] + recipes.suffix(1).map(item)).joined(separator: ",")
        return decode(#"{"data": {"categories": [\#(categories)], "most_saved": [\#(mostSaved)]}}"#)
    }

    static var term: GroupedSearchResults {
        let users = ["lucia", "averyverylongusername_thirty"]
            .enumerated()
            .map { #"{"id": \#($0.offset + 500), "username": "\#($0.element)", "profile_photo_url": null}"# }
            .joined(separator: ",")
        let everyone = (recipes.map(item) + [ad]).joined(separator: ",")
        return decode(#"""
        {"data": {"users": [\#(users)], "tray": [\#(recipes[0])], "following": [\#(recipes[1]), \#(recipes[2])],
                  "everyone": [\#(everyone)]}}
        """#)
    }

    static var ingredients: IngredientSearchResults {
        let ready = #"{"post": \#(recipes[0]), "missing": [], "scope": "mine"}"#
        let almost = [
            #"{"post": \#(recipes[1]), "missing": ["soy sauce", "ginger"], "scope": "following"}"#,
            #"{"post": \#(recipes[3]), "missing": ["lemon"], "scope": "everyone"}"#,
        ].joined(separator: ",")
        return decode(#"{"data": {"everything": [\#(ready)], "almost": [\#(almost)]}}"#)
    }
}

/// The field and chips that sit above every Search state on the real screen,
/// so each preview shows where the search is edited, not just its results.
private struct SearchPreviewHeader: View {
    @State var query: String
    @State var chips: [String]
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SearchField(
                text: $query,
                isFocused: $focused,
                showsClear: !query.isEmpty || !chips.isEmpty,
                onSubmit: {},
                onClear: {
                    query = ""
                    chips = []
                }
            )
            .padding(.horizontal, HomeMetrics.inset)
            if !chips.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(chips, id: \.self) { chip in
                        IngredientChip(name: chip) { chips.removeAll { $0 == chip } }
                    }
                }
                .padding(.top, 12)
                .padding(.horizontal, HomeMetrics.inset)
            }
        }
    }
}

private struct SearchPreviewScreen<Content: View>: View {
    var query = ""
    var chips: [String] = []
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    SearchPreviewHeader(query: query, chips: chips)
                    content()
                }
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Theme.background)
        }
    }
}

private func browse() -> some View {
    SearchPreviewScreen { SearchBrowseContent(browse: SearchPreviewData.browse) { _ in } }
}

private func term() -> some View {
    SearchPreviewScreen(query: "chicken") { SearchTermContent(results: SearchPreviewData.term) { _ in } }
}

private func ingredients() -> some View {
    SearchPreviewScreen(chips: ["chicken", "rice"]) {
        IngredientMatchContent(chips: ["chicken", "rice"], results: SearchPreviewData.ingredients)
    }
}

private func noMatches() -> some View {
    SearchPreviewScreen(query: "zzz") {
        EmptyStateBlock(
            title: "No results yet.",
            subtitle: "Try a different recipe, ingredient, or cook.",
            topPadding: 56,
            chrome: .plain
        )
        EmptyStateBlock(
            title: "No matches yet.",
            subtitle: "Try removing an ingredient.",
            topPadding: 56,
            chrome: .plain
        )
    }
}

private func loading() -> some View {
    SearchPreviewScreen(query: "chicken") {
        SearchTermSkeleton()
        SearchIngredientSkeleton()
    }
}

#Preview("Search a browse · light") { browse() }
#Preview("Search a browse · dark") { browse().preferredColorScheme(.dark) }
#Preview("Search a browse · largest text") { browse().dynamicTypeSize(.accessibility5) }
#Preview("Search b one term · light") { term() }
#Preview("Search b one term · dark") { term().preferredColorScheme(.dark) }
#Preview("Search b one term · largest text") { term().dynamicTypeSize(.accessibility5) }
#Preview("Search c ingredients · light") { ingredients() }
#Preview("Search c ingredients · dark") { ingredients().preferredColorScheme(.dark) }
#Preview("Search c ingredients · largest text") { ingredients().dynamicTypeSize(.accessibility5) }
#Preview("Search d no matches · light") { noMatches() }
#Preview("Search d no matches · dark") { noMatches().preferredColorScheme(.dark) }
#Preview("Search e loading · light") { loading() }
#Preview("Search e loading · dark") { loading().preferredColorScheme(.dark) }
#Preview("Search browse error · light") {
    SearchPreviewScreen { SearchLoadErrorView {} }
}
