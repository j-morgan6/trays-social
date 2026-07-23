@testable import TraysSocial
import XCTest

/// W158: decoding coverage for the discriminated-union feed.
///
/// The server sends tagged items ({"type":"post","post":{...}} /
/// {"type":"ad","ad":{...}}) when ads are enabled, and legacy flat
/// [Post] arrays when disabled. `FeedItem`'s custom decoder keys the
/// flat-vs-tagged split on the PRESENCE of the nested "post"/"ad"
/// containers — NOT the "type" value — because a flat Post carries its
/// own "type" field whose value can be "post" (the aliasing trap).
final class FeedItemDecodingTests: XCTestCase {
    /// Matches APIClient's decoder configuration (Services/APIClient.swift).
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func postJSON(id: Int, type: String = "recipe") -> String {
        """
        {
            "id": \(id),
            "type": "\(type)",
            "caption": "Test post \(id)",
            "cooking_time_minutes": null,
            "servings": null,
            "like_count": 3,
            "comment_count": 1,
            "liked_by_current_user": false,
            "bookmarked_by_current_user": false,
            "inserted_at": "2026-07-01T12:00:00Z",
            "user": {"id": 1, "username": "alice", "profile_photo_url": null},
            "photos": [],
            "ingredients": [],
            "cooking_steps": [],
            "tools": [],
            "tags": []
        }
        """
    }

    // MARK: - Tagged union

    func test_taggedUnion_decodesPostAndAdItems() throws {
        let json = """
        [
            {"type": "post", "post": \(postJSON(id: 10))},
            {"type": "ad", "ad": {"slot": 0, "placement": "feed"}}
        ]
        """
        let items = try decoder.decode([FeedItem].self, from: Data(json.utf8))

        XCTAssertEqual(items.count, 2)
        XCTAssertEqual(items[0].post?.id, 10)
        guard case let .ad(_, slot) = items[1] else {
            return XCTFail("expected .ad, got \(items[1])")
        }
        XCTAssertEqual(slot.slot, 0)
        XCTAssertEqual(slot.placement, "feed")
    }

    // MARK: - Legacy flat arrays

    func test_legacyFlatArray_decodesToPostItems() throws {
        // Includes a post whose own content "type" is "post" — the
        // aliasing trap. Disambiguation must NOT key on the type value.
        let json = "[\(postJSON(id: 1, type: "recipe")), \(postJSON(id: 2, type: "post"))]"
        let items = try decoder.decode([FeedItem].self, from: Data(json.utf8))

        XCTAssertEqual(items.compactMap(\.post?.id), [1, 2])
        XCTAssertEqual(items.compactMap(\.post?.type), ["recipe", "post"])
    }

    // MARK: - Forward compatibility

    func test_unknownDiscriminator_decodesToUnknown_siblingsUnaffected() throws {
        let json = """
        [
            {"type": "post", "post": \(postJSON(id: 5))},
            {"type": "banner", "ad": {"slot": 0, "placement": "feed"}},
            {"type": "ad", "ad": {"slot": 1, "placement": "feed"}}
        ]
        """
        let items = try decoder.decode([FeedItem].self, from: Data(json.utf8))

        XCTAssertEqual(items.count, 3)
        XCTAssertEqual(items[0].post?.id, 5)
        guard case .unknown = items[1] else {
            return XCTFail("expected .unknown, got \(items[1])")
        }
        guard case let .ad(_, slot) = items[2] else {
            return XCTFail("expected .ad, got \(items[2])")
        }
        XCTAssertEqual(slot.slot, 1)
    }

    // MARK: - Ad identity

    func test_adIds_uniqueAcrossTwoDecodesOfSamePayload() throws {
        // Server slot indices repeat per page; ForEach identity comes
        // from a fresh client-side UUID minted at decode time.
        let json = """
        [{"type": "ad", "ad": {"slot": 0, "placement": "feed"}}]
        """
        let first = try decoder.decode([FeedItem].self, from: Data(json.utf8))
        let second = try decoder.decode([FeedItem].self, from: Data(json.utf8))

        XCTAssertNotEqual(first[0].id, second[0].id)
    }

    // MARK: - AdAwarePaginatedResponse

    func test_adAwareResponse_cursorAndAdConfigPassThrough() throws {
        let json = """
        {
            "data": [
                {"type": "post", "post": \(postJSON(id: 1))},
                {"type": "ad", "ad": {"slot": 0, "placement": "feed"}}
            ],
            "cursor": "abc123",
            "ad_config": {"enabled": true, "frequency": 5}
        }
        """
        let response = try decoder.decode(
            AdAwarePaginatedResponse<[FeedItem]>.self, from: Data(json.utf8)
        )

        XCTAssertEqual(response.cursor, "abc123")
        XCTAssertEqual(response.adConfig?.enabled, true)
        XCTAssertEqual(response.adConfig?.frequency, 5)
        XCTAssertEqual(response.data.count, 2)
    }

    func test_adAwareResponse_decodesWithoutAdConfigOrCursor() throws {
        // Legacy shape (ads disabled): flat posts, no cursor, no ad_config —
        // the trending endpoint's response.
        let json = """
        {"data": [\(postJSON(id: 7))]}
        """
        let response = try decoder.decode(
            AdAwarePaginatedResponse<[FeedItem]>.self, from: Data(json.utf8)
        )

        XCTAssertNil(response.cursor)
        XCTAssertNil(response.adConfig)
        XCTAssertEqual(response.data.compactMap(\.post?.id), [7])
    }

    // MARK: - FeedViewModel item helpers

    @MainActor
    func test_applyPostUpdate_skipsAds_andUpdatesMatchingPost() throws {
        let json = """
        [
            {"type": "post", "post": \(postJSON(id: 1))},
            {"type": "ad", "ad": {"slot": 0, "placement": "feed"}},
            {"type": "post", "post": \(postJSON(id: 2))}
        ]
        """
        let vm = FeedViewModel()
        vm.items = try decoder.decode([FeedItem].self, from: Data(json.utf8))
        guard let target = vm.items.last?.post else {
            return XCTFail("fixture should end in a post")
        }

        let updated = Post(
            id: target.id, type: target.type, caption: "Edited caption",
            cookingTimeMinutes: target.cookingTimeMinutes, servings: target.servings,
            likeCount: target.likeCount, commentCount: target.commentCount,
            likedByCurrentUser: target.likedByCurrentUser,
            bookmarkedByCurrentUser: target.bookmarkedByCurrentUser,
            insertedAt: target.insertedAt, user: target.user, photos: target.photos,
            ingredients: target.ingredients, cookingSteps: target.cookingSteps,
            tools: target.tools, tags: target.tags
        )
        vm.applyPostUpdate(updated)

        // The ad slot survives untouched in place; the post row updated.
        guard case .ad = vm.items[1] else {
            return XCTFail("ad slot should be untouched")
        }
        XCTAssertEqual(vm.items[2].post?.caption, "Edited caption")
        XCTAssertEqual(vm.items[0].post?.caption, "Test post 1")
    }
}
