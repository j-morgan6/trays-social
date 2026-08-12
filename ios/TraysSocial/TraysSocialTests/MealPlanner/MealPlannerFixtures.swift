import Foundation
@testable import TraysSocial

/// Shared fixtures for the meal-planner tests.
///
/// Hoisted out of the test classes when `MealPlannerViewModelTests` grew past
/// this project's own 400-line file limit and had to be split three ways — the
/// alternative was three copies of the same builders, which is how test
/// fixtures drift apart from each other and from the models they stand in for.
enum PlannerFixtures {
    /// A Wednesday, so `today` sits mid-week and the surrounding days are all
    /// real dates rather than boundaries.
    static let today = PlannerFixtures.date("2026-03-04")

    /// Pinned to a fixed week so no test depends on the wall clock.
    @MainActor
    static func makeViewModel() -> MealPlannerViewModel {
        MealPlannerViewModel(week: .containing(today), today: today)
    }

    static func date(_ key: String) -> Date {
        guard let date = PlannerWireDate.date(from: key) else {
            preconditionFailure("bad fixture date \(key)")
        }
        return date
    }

    /// The checked state of one grocery item, wherever it sits in the groups.
    @MainActor
    static func checked(_ viewModel: MealPlannerViewModel, _ key: String) -> Bool? {
        viewModel.groceryGroups
            .flatMap(\.items)
            .first { $0.itemKey == key }?
            .checked
    }

    static func entry(id: Int, date: String, postID: Int) -> MealPlanEntry {
        MealPlanEntry(id: id, date: date, post: plannedPost(id: postID))
    }

    static func plannedPost(id: Int) -> PlannedPost {
        PlannedPost(
            id: id, caption: "A recipe", thumbnailUrl: nil,
            cookingTimeMinutes: 20, type: "recipe"
        )
    }

    static func group(postID: Int, keys: [String], checked: Bool = false) -> GroceryGroup {
        GroceryGroup(
            post: plannedPost(id: postID),
            items: keys.map {
                GroceryItem(itemKey: $0, name: "Salt", quantity: "1", unit: "tsp", checked: checked)
            }
        )
    }

    /// Mirrors the `post(...)` helper in CollectionsViewModelTests.
    static func post(id: Int) -> Post {
        Post(
            id: id, type: "recipe", caption: "A recipe",
            cookingTimeMinutes: nil, servings: nil,
            likeCount: 0, commentCount: 0,
            likedByCurrentUser: false,
            bookmarkedByCurrentUser: true,
            insertedAt: Date(),
            user: PostUser(id: 1, username: "alice", profilePhotoUrl: nil),
            photos: [], ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }
}
