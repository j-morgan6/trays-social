import Foundation

struct User: Codable, Identifiable {
    let id: Int
    let username: String
    let email: String?
    let bio: String?
    let profilePhotoUrl: String?
    let insertedAt: Date?

    // Profile-specific fields (optional, not always present)
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?
    let followedByCurrentUser: Bool?
}

struct AuthResponse: Decodable {
    let token: String
    let user: User
    let needsUsername: Bool?
}
