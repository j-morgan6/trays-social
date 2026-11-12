import SwiftUI

// W241: preview galleries for every Home state (light, dark, largest text).
// Photos and avatars are nil, so the cream placeholders show.

private enum HomePreviewData {
    static let greeting = HomeGreetingHeader.Greeting(
        kicker: "Thursday evening",
        question: "What are you cooking, ren?"
    )

    private static func iso(hoursAgo: Double) -> String {
        ISO8601DateFormatter().string(from: Date().addingTimeInterval(-hoursAgo * 3600))
    }

    private static func post(_ id: Int, _ caption: String, minutes: Int, cook: String, hoursAgo: Double) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "\(caption)", "cooking_time_minutes": \(minutes),
         "servings": 2, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "\(iso(hoursAgo: hoursAgo))",
         "user": {"id": \(id + 100), "username": "\(cook)", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    private static let jumpBackIn = [
        post(1, "Miso butter salmon", minutes: 25, cook: "ren", hoursAgo: 300),
        post(2, "Sheet-pan gnocchi with sausage and a very long title that wraps", minutes: 35, cook: "noor",
             hoursAgo: 400),
        post(3, "Lemon herb roast chicken", minutes: 90, cook: "lucia", hoursAgo: 500),
        post(4, "Weeknight dal", minutes: 40, cook: "ren", hoursAgo: 600),
    ].joined(separator: ",")

    private static let newRow = [
        post(11, "Harissa chickpea stew", minutes: 40, cook: "noor", hoursAgo: 3),
        post(12, "Ginger chicken rice bowls", minutes: 30, cook: "maya", hoursAgo: 30),
        post(13, "Peanut noodles", minutes: 20, cook: "jonah", hoursAgo: 80),
    ].joined(separator: ",")

    private static let friends = (1 ... 6).map { index in
        let names = ["maya", "jonah", "noor", "lucia", "sam", "averyverylongusername"]
        return #"{"id": \#(200 + index), "username": "\#(names[index - 1])", "profile_photo_url": null, "#
            + #""last_posted_at": "\#(iso(hoursAgo: Double(index)))"}"#
    }.joined(separator: ",")

    private static let cooks = (1 ... 3).map { index in
        let names = ["maya", "jonah", "noor"]
        return #"{"id": \#(300 + index), "username": "\#(names[index - 1])", "profile_photo_url": null, "#
            + #""recipe_count": \#(index * 7)}"#
    }.joined(separator: ",")

    private static let tonight = #"""
    {"id": 1, "date": "2026-11-12", "post": {"id": 2, "caption": "Sheet-pan gnocchi with sausage",
     "thumbnail_url": null, "cooking_time_minutes": 35, "type": "recipe"}}
    """#

    static func payload(
        jumpBackIn: Bool = true,
        tonight: Bool = true,
        friends: Bool = true,
        newRow: Bool = true,
        cooks: Bool = false
    ) -> HomePayload {
        let json = """
        {"data": {"jump_back_in": [\(jumpBackIn ? Self.jumpBackIn : "")],
                  "tonight": \(tonight ? Self.tonight : "null"),
                  "friends_trays": [\(friends ? Self.friends : "")],
                  "new_from_following": [\(newRow ? Self.newRow : "")],
                  "suggested_cooks": [\(cooks ? Self.cooks : "")]}}
        """
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        // Fixed sample data; a decode failure here is a preview authoring bug.
        // swiftlint:disable:next force_try
        return try! decoder.decode(DataResponse<HomePayload>.self, from: Data(json.utf8)).data
    }
}

private struct HomePreviewScreen<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        NavigationStack {
            ScrollView {
                content()
                    .padding(.top, 24)
                    .padding(.bottom, 40)
            }
            .background(Theme.background)
        }
    }
}

private func loaded(_ payload: HomePayload) -> some View {
    HomePreviewScreen {
        HomeContentView(payload: payload, greeting: HomePreviewData.greeting)
    }
}

#Preview("Home full · light") {
    loaded(HomePreviewData.payload())
}

#Preview("Home full · dark") {
    loaded(HomePreviewData.payload()).preferredColorScheme(.dark)
}

#Preview("Home full · largest text") {
    loaded(HomePreviewData.payload()).dynamicTypeSize(.accessibility5)
}

#Preview("Home no Tonight, nothing new · light") {
    loaded(HomePreviewData.payload(tonight: false, newRow: false))
}

#Preview("Home new user · light") {
    loaded(HomePreviewData.payload(jumpBackIn: false, tonight: false, friends: false, newRow: false, cooks: true))
}

#Preview("Home new user · dark") {
    loaded(HomePreviewData.payload(jumpBackIn: false, tonight: false, friends: false, newRow: false, cooks: true))
        .preferredColorScheme(.dark)
}

#Preview("Home new user · largest text") {
    loaded(HomePreviewData.payload(jumpBackIn: false, tonight: false, friends: false, newRow: false, cooks: true))
        .dynamicTypeSize(.accessibility5)
}

#Preview("Home loading · light") {
    HomePreviewScreen { HomeLoadingView() }
}

#Preview("Home loading · dark") {
    HomePreviewScreen { HomeLoadingView() }.preferredColorScheme(.dark)
}

#Preview("Home error · light") {
    HomePreviewScreen { HomeErrorView {} }
}

#Preview("Home error · dark") {
    HomePreviewScreen { HomeErrorView {} }
        .preferredColorScheme(.dark)
}
