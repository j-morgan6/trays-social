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

    private static func decode<T: Decodable & Sendable>(_ json: String) -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        // Fixed sample data; a decode failure here is a preview authoring bug.
        // swiftlint:disable:next force_try
        return try! decoder.decode(T.self, from: Data(json.utf8))
    }
}
