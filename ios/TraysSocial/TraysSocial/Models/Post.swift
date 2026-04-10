import Foundation

struct Post: Codable, Identifiable, Sendable {
    let id: Int
    let type: String
    let caption: String?
    let cookingTimeMinutes: Int?
    let servings: Int?
    let likeCount: Int
    let commentCount: Int
    let likedByCurrentUser: Bool
    let bookmarkedByCurrentUser: Bool?
    let insertedAt: Date
    let user: PostUser
    let photos: [PostPhoto]
    let ingredients: [Ingredient]
    let cookingSteps: [CookingStep]
    let tools: [Tool]
    let tags: [String]

    var isRecipe: Bool { type == "recipe" }

    var primaryPhotoURL: String? {
        photos.sorted(by: { $0.position < $1.position }).first?.url
    }

    var thumbURL: String? {
        photos.sorted(by: { $0.position < $1.position }).first?.thumbUrl
    }
}

struct PostUser: Codable, Identifiable, Sendable {
    let id: Int
    let username: String
    let profilePhotoUrl: String?
}

struct PostPhoto: Codable, Sendable {
    let url: String
    let thumbUrl: String?
    let mediumUrl: String?
    let position: Int
}

struct Ingredient: Codable, Identifiable, Sendable {
    var id: String { "\(name)-\(quantity ?? "")" }
    let name: String
    let quantity: String?
    let unit: String?
}

struct CookingStep: Codable, Identifiable, Sendable {
    var id: Int { position }
    let position: Int
    let instruction: String
}

struct Tool: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
}
