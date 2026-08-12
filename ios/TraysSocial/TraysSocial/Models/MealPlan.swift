import Foundation

/// The recipe summary embedded in every meal-plan and grocery-list response.
///
/// This is NOT the app's `Post`: the API returns five keys here (three on the
/// grocery endpoint) while `Post` requires `photos`, `ingredients`, `user`,
/// `likeCount` and more, all non-optional. Decoding one into the other is not
/// possible, and inventing the missing values would put a fake `PostUser` on
/// screen.
///
/// One type for both endpoints rather than two near-identical structs:
/// `cookingTimeMinutes` and `type` are simply absent from the grocery payload.
/// Two structs would let the same concept drift apart under maintenance, which
/// is the drift the W173 server-side review already had to correct once.
struct PlannedPost: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let caption: String?
    let thumbnailUrl: String?
    /// Absent on the grocery-list payload.
    let cookingTimeMinutes: Int?
    /// Absent on the grocery-list payload.
    let type: String?

    var thumbURL: URL? {
        thumbnailUrl?.asBackendURL
    }

    var title: String {
        RecipeTitle.from(caption: caption)
    }

    /// Optimistic projection of a tray recipe onto the shape the server will
    /// echo back, so a pending card renders identically to the confirmed one.
    init(from post: Post) {
        id = post.id
        caption = post.caption
        thumbnailUrl = post.thumbURL ?? post.primaryPhotoURL
        cookingTimeMinutes = post.cookingTimeMinutes
        type = post.type
    }

    init(id: Int, caption: String?, thumbnailUrl: String?, cookingTimeMinutes: Int?, type: String?) {
        self.id = id
        self.caption = caption
        self.thumbnailUrl = thumbnailUrl
        self.cookingTimeMinutes = cookingTimeMinutes
        self.type = type
    }
}

/// One recipe planned on one day.
///
/// `date` is a `String`, not a `Date`: the API sends a bare `YYYY-MM-DD`, and
/// `APIClient`'s decoder uses `.iso8601`, which rejects a date with no time
/// component and would throw on the whole payload. Keeping it as the wire
/// string also means the value posted back is byte-identical to the one
/// received.
struct MealPlanEntry: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let date: String
    let post: PlannedPost

    /// Optimistic rows carry a negative id until the server assigns a real one.
    /// Nothing may `DELETE /meal-plan/entries/-1`.
    var isPending: Bool {
        id < 0
    }
}

/// One ingredient line on the grocery checklist.
struct GroceryItem: Codable, Identifiable, Sendable, Hashable {
    /// Opaque `"<post_id>:<ingredient_id>"` from the server. Treated as a
    /// string and never parsed or reconstructed client-side.
    let itemKey: String
    let name: String
    let quantity: String?
    let unit: String?
    let checked: Bool

    var id: String {
        itemKey
    }

    /// The recipe's own words for how much, joined verbatim.
    ///
    /// No parsing, no unit conversion, no summing — this is string
    /// concatenation of two server fields and must stay that way. Quantity
    /// math across recipes is exactly the "shoppable list" the product's north
    /// star rules out.
    var measure: String? {
        let parts = [quantity, unit].compactMap { $0?.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    func withChecked(_ newValue: Bool) -> GroceryItem {
        GroceryItem(itemKey: itemKey, name: name, quantity: quantity, unit: unit, checked: newValue)
    }
}

/// The checklist for one planned recipe. Grouping is per recipe, always — items
/// are never merged across recipes.
struct GroceryGroup: Codable, Identifiable, Sendable, Hashable {
    let post: PlannedPost
    let items: [GroceryItem]

    var id: Int {
        post.id
    }

    func replacingItem(key: String, checked: Bool) -> GroceryGroup {
        GroceryGroup(
            post: post,
            items: items.map { $0.itemKey == key ? $0.withChecked(checked) : $0 }
        )
    }

    /// Re-applies locally-toggled values on top of a fresh server payload, for
    /// the keys whose writes are still in flight. Without this, a refetch that
    /// lands mid-write repaints the box at its pre-toggle value and the user
    /// watches their tap undo itself.
    func preservingChecks(from local: [String: Bool], keys: Set<String>) -> GroceryGroup {
        GroceryGroup(
            post: post,
            items: items.map { item in
                guard keys.contains(item.itemKey), let value = local[item.itemKey] else { return item }
                return item.withChecked(value)
            }
        )
    }
}

struct MealPlanWeekPayload: Decodable, Sendable {
    let weekStart: String
    let entries: [MealPlanEntry]
}

struct GroceryListPayload: Decodable, Sendable {
    let weekStart: String
    let recipes: [GroceryGroup]
}

struct CreateEntryBody: Encodable, Sendable {
    /// The exact planned day, NOT the week's Monday — only week *reads* are
    /// normalized server-side.
    let date: String
    let postId: Int
}

struct GroceryCheckBody: Encodable, Sendable {
    let weekStart: String
    let itemKey: String
    let checked: Bool
}
