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

    /// Admin flag — set server-side via the :admin_emails allowlist (auto-grant
    /// on registration) or by an existing admin via Accounts.set_admin/2.
    /// Optional in the decoder so older API responses without the key still
    /// parse; treated as `false` when absent or null.
    let isAdmin: Bool?

    var isEmailConfirmed: Bool {
        confirmedAt != nil
    }

    var hasAdminAccess: Bool {
        isAdmin == true
    }
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: User
    let needsUsername: Bool?
}
