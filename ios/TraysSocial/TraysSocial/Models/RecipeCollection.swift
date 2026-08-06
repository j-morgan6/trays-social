import Foundation

/// A user's custom collection of saved recipes (W177, backed by the W172 API).
///
/// Named `RecipeCollection`, NOT `Collection`: a type named `Collection`
/// shadows `Swift.Collection` module-wide and breaks every generic constrained
/// to it, in error messages that point nowhere near the real cause.
///
/// The properties are `let`. Optimistic updates build a replacement value via
/// the helpers below rather than mutating in place, which keeps every
/// transition a pure function the tests can assert directly — the same shape
/// `Post.withFollowedByCurrentUser` established.
struct RecipeCollection: Codable, Identifiable, Sendable, Hashable {
    let id: Int
    let name: String
    let itemCount: Int
    /// Relative `/uploads/...` path from the backend; resolve with `.asBackendURL`.
    /// The server derives it from the newest item's position-0 photo, so it
    /// changes on every add.
    let coverPhotoUrl: String?
    let insertedAt: Date

    /// Rows created optimistically carry a negative id until the server
    /// assigns a real one. Nothing may navigate into a pending collection —
    /// `GET /collections/-1` is a 404.
    var isPending: Bool {
        id < 0
    }

    var coverURL: URL? {
        coverPhotoUrl?.asBackendURL
    }

    func renamed(to newName: String) -> RecipeCollection {
        RecipeCollection(
            id: id, name: newName, itemCount: itemCount,
            coverPhotoUrl: coverPhotoUrl, insertedAt: insertedAt
        )
    }

    func withItemCount(_ count: Int) -> RecipeCollection {
        RecipeCollection(
            id: id, name: name, itemCount: max(0, count),
            coverPhotoUrl: coverPhotoUrl, insertedAt: insertedAt
        )
    }

    /// Optimistic add. The cover moves too: the server's `cover_photo_url` is
    /// the position-0 photo of the *newest* item, so an add always takes the
    /// added post's photo. Restoring the whole value on rollback is what keeps
    /// the count and the cover from ever desyncing.
    func addingItem(coverPhotoUrl newCover: String?) -> RecipeCollection {
        RecipeCollection(
            id: id, name: name, itemCount: itemCount + 1,
            coverPhotoUrl: newCover ?? coverPhotoUrl, insertedAt: insertedAt
        )
    }

    func removingItem() -> RecipeCollection {
        withItemCount(itemCount - 1)
    }
}
