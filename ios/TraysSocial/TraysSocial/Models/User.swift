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

    /// Paid-tier entitlement (G38/W160) — set server-side only via
    /// Accounts.set_subscriber/2 from a verified purchase. Optional so older
    /// API responses without the key still parse; treated as `false` when
    /// absent or null. The client uses this to suppress ads and unlock the
    /// utility bundle. Never gates recipe content (monetization north star).
    let isSubscriber: Bool?

    var isEmailConfirmed: Bool {
        confirmedAt != nil
    }

    /// Copy with only the follow state changed. Centralizes the manual
    /// memberwise reconstruction (a missed argument here broke the build
    /// in D102) so optimistic follow toggles never snapshot whole objects.
    func withFollowedByCurrentUser(_ followed: Bool) -> User {
        User(
            id: id, username: username, email: email, bio: bio,
            profilePhotoUrl: profilePhotoUrl, insertedAt: insertedAt,
            confirmedAt: confirmedAt, postCount: postCount,
            followerCount: followerCount, followingCount: followingCount,
            followedByCurrentUser: followed, isAdmin: isAdmin,
            isSubscriber: isSubscriber
        )
    }

    var hasAdminAccess: Bool {
        isAdmin == true
    }

    /// True when the user holds the paid-tier entitlement (ad-free + utility
    /// bundle). Use this for client-side gating once W160 ships its features.
    var hasActiveSubscription: Bool {
        isSubscriber == true
    }
}

struct AuthResponse: Decodable, Sendable {
    let token: String
    let user: User
    let needsUsername: Bool?
}
