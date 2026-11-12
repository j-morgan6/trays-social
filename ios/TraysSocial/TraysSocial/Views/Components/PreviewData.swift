import Foundation

/// W245: sample posts, users and collections for the My Tray, collection
/// and profile preview galleries. Photos and avatars are nil, so the cream
/// placeholders show.
enum PreviewData {
    static func post(
        _ id: Int,
        _ caption: String,
        minutes: Int? = 30,
        cook: String = "ren",
        type: String = "recipe",
        hoursAgo: Int = 3
    ) -> Post {
        let insertedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(Double(-hoursAgo) * 3600))
        let time = minutes.map(String.init) ?? "null"
        let json = """
        {"id": \(id), "type": "\(type)", "caption": "\(caption)", "cooking_time_minutes": \(time),
         "servings": 2, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "\(insertedAt)",
         "user": {"id": \(cook == "ren" ? 1 : id + 100), "username": "\(cook)", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
        return decode(json)
    }

    static func user(
        _ username: String,
        bio: String? = nil,
        counts: (posts: Int, followers: Int) = (7, 120),
        following: Bool? = nil
    ) -> User {
        User(
            id: username == "ren" ? 1 : 2,
            username: username,
            email: nil,
            bio: bio,
            profilePhotoUrl: nil,
            insertedAt: nil,
            confirmedAt: nil,
            postCount: counts.posts,
            followerCount: counts.followers,
            followingCount: 48,
            followedByCurrentUser: following,
            isAdmin: nil,
            isSubscriber: nil
        )
    }

    static func collection(_ id: Int, _ name: String, count: Int) -> RecipeCollection {
        RecipeCollection(id: id, name: name, itemCount: count, coverPhotoUrl: nil, insertedAt: Date())
    }

    static let ownRecipes = [
        post(1, "Sesame chicken thighs", minutes: 35, hoursAgo: 5),
        post(2, "Miso butter salmon with a long title that wraps", minutes: 25, hoursAgo: 30),
        post(3, "Weeknight dal", minutes: 40, hoursAgo: 80),
    ]

    static let saved = [
        post(4, "Harissa chickpea stew", minutes: 40, cook: "noor"),
        post(5, "Peanut noodles", minutes: 20, cook: "sam"),
    ]

    static let legacyPhoto = post(6, "Saturday market haul", minutes: nil, type: "photo", hoursAgo: 900)

    static let collections = [
        collection(1, "Weeknights", count: 18),
        collection(2, "For guests and long Sunday lunches", count: 1),
        collection(3, "Baking project", count: 0),
    ]

    /// W247: a full recipe for the recipe detail and Cook mode galleries:
    /// tags, a cook's note, ingredients (one listed twice), steps and tools.
    static let recipeCaption = "Sesame chicken thighs. Crisp skin, sticky glaze, ready while the rice cooks."

    static func recipe(
        caption: String = recipeCaption,
        saved: Bool = false,
        liked: Bool = false
    ) -> Post {
        let insertedAt = ISO8601DateFormatter().string(from: Date().addingTimeInterval(-5 * 3600))
        let json = """
        {"id": 41, "type": "recipe", "caption": "\(caption)", "cooking_time_minutes": 35,
         "servings": 4, "like_count": 12, "comment_count": 2, "liked_by_current_user": \(liked),
         "bookmarked_by_current_user": \(saved), "inserted_at": "\(insertedAt)",
         "user": {"id": 2, "username": "noor", "profile_photo_url": null},
         "photos": [], "tags": ["weeknight", "chicken", "sheet pan"],
         "ingredients": [
           {"name": "chicken thighs", "quantity": "6", "unit": null},
           {"name": "toasted sesame oil", "quantity": "2", "unit": "tbsp"},
           {"name": "honey", "quantity": "1", "unit": "tbsp"},
           {"name": "spring onions", "quantity": null, "unit": null},
           {"name": "honey", "quantity": "1", "unit": "tbsp"}
         ],
         "cooking_steps": [
           {"position": 1, "instruction": "Heat the oven to 220C and line a tray."},
           {"position": 2, "instruction": "Toss the thighs with the oil, honey and a big pinch of salt."},
           {"position": 3, "instruction": "Roast skin side up for 30 minutes, until crisp and sticky."}
         ],
         "tools": [{"name": "Sheet pan"}, {"name": "Tongs"}]}
        """
        return decode(json)
    }

    static let comments: [Comment] = [
        Comment(
            id: 1,
            body: "Made this twice this week. The glaze is the whole thing.",
            insertedAt: Date().addingTimeInterval(-3600),
            user: PostUser(id: 3, username: "sam", profilePhotoUrl: nil)
        ),
        Comment(
            id: 2,
            body: "Thanks! Add chilli flakes to the glaze if you like heat.",
            insertedAt: Date().addingTimeInterval(-1800),
            user: PostUser(id: 2, username: "noor", profilePhotoUrl: nil)
        ),
    ]

    private static func decode<T: Decodable & Sendable>(_ json: String) -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        // Fixed sample data; a decode failure here is a preview authoring bug.
        // swiftlint:disable:next force_try
        return try! decoder.decode(T.self, from: Data(json.utf8))
    }
}
