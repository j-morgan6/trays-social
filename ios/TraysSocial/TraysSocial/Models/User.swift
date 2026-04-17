import Foundation

struct User: Codable, Identifiable, Sendable {
    let id: Int
    let username: String
    let email: String?
    let bio: String?
    let profilePhotoUrl: String?
    let insertedAt: Date?
    let confirmedAt: Date?

    // Profile-specific fields (optional, not always present)
    let postCount: Int?
    let followerCount: Int?
    let followingCount: Int?
    let followedByCurrentUser: Bool?

    var isEmailConfirmed: Bool { confirmedAt != nil }
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: User
    let needsUsername: Bool?
}
