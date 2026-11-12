import Foundation

/// Response of `GET /api/v1/home`.
struct HomePayload: Decodable, Sendable {
    let jumpBackIn: [Post]
    let tonight: MealPlanEntry?
    let friendsTrays: [FriendTray]
    let newFromFollowing: [Post]
    let suggestedCooks: [SuggestedCook]
}

struct FriendTray: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    let username: String
    let profilePhotoUrl: String?
    /// Nil when the friend has not posted a recipe yet.
    let lastPostedAt: Date?
}

struct SuggestedCook: Decodable, Identifiable, Sendable, Hashable {
    let id: Int
    let username: String
    let profilePhotoUrl: String?
    let recipeCount: Int
}

/// Pure decisions for what Home renders. Kept out of the view because this
/// project has no view-test infrastructure (see MealPlanGating).
/// Which Home screen to show. A payload always wins; with none, a failed
/// first load shows the error block unless a retry is already in flight.
enum HomeScreenState: Equatable {
    case content
    case error
    case loading

    static func decide(hasPayload: Bool, loadFailed: Bool, isLoading: Bool) -> HomeScreenState {
        if hasPayload {
            return .content
        }
        return loadFailed && !isLoading ? .error : .loading
    }
}

enum HomeLayout {
    /// Brand-new user: nothing in the tray and nobody followed.
    static func showsWelcome(_ payload: HomePayload) -> Bool {
        payload.jumpBackIn.isEmpty && payload.friendsTrays.isEmpty
    }

    /// The finite "New from people you follow" row appears once the viewer
    /// follows anyone, even if it only holds the caught-up card.
    static func showsNewRow(_ payload: HomePayload) -> Bool {
        !payload.friendsTrays.isEmpty
    }
}
