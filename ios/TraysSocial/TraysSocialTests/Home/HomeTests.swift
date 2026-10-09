@testable import TraysSocial
import XCTest

@MainActor
final class HomeTests: XCTestCase {
    private var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }

    private func postJSON(id: Int) -> String {
        """
        {"id": \(id), "type": "recipe", "caption": "Pho", "cooking_time_minutes": 60,
         "servings": 2, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-10-01T12:00:00Z",
         "user": {"id": 2, "username": "maria", "profile_photo_url": null},
         "photos": [], "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}
        """
    }

    private func payload(
        jumpBackIn: String = "[]",
        friends: String = "[]",
        newRow: String = "[]",
        cooks: String = "[]",
        tonight: String = "null"
    ) throws -> HomePayload {
        let json = """
        {"data": {"jump_back_in": \(jumpBackIn), "tonight": \(tonight), "friends_trays": \(friends),
                  "new_from_following": \(newRow), "suggested_cooks": \(cooks)}}
        """
        return try decoder.decode(DataResponse<HomePayload>.self, from: Data(json.utf8)).data
    }

    func test_decodesEverySection() throws {
        let home = try payload(
            jumpBackIn: "[\(postJSON(id: 1))]",
            friends: #"[{"id": 2, "username": "maria", "profile_photo_url": null, "last_posted_at": "2026-10-07T18:00:00Z"}]"#,
            newRow: "[\(postJSON(id: 3))]",
            cooks: #"[{"id": 9, "username": "dan", "profile_photo_url": null, "recipe_count": 4}]"#,
            tonight: #"{"id": 5, "date": "2026-10-08", "post": {"id": 1, "caption": "Pho", "thumbnail_url": null, "cooking_time_minutes": 60, "type": "recipe"}}"#
        )
        XCTAssertEqual(home.jumpBackIn.map(\.id), [1])
        XCTAssertEqual(home.tonight?.post.id, 1)
        XCTAssertEqual(home.friendsTrays.first?.username, "maria")
        XCTAssertNotNil(home.friendsTrays.first?.lastPostedAt)
        XCTAssertEqual(home.newFromFollowing.map(\.id), [3])
        XCTAssertEqual(home.suggestedCooks.first?.recipeCount, 4)
    }

    func test_friendWithNoRecipesDecodesNilDate() throws {
        let home = try payload(friends: #"[{"id": 2, "username": "q", "profile_photo_url": null, "last_posted_at": null}]"#)
        XCTAssertNil(home.friendsTrays.first?.lastPostedAt)
    }

    func test_welcomeOnlyForEmptyTrayAndNoFollows() throws {
        XCTAssertTrue(try HomeLayout.showsWelcome(payload()))
        XCTAssertFalse(try HomeLayout.showsWelcome(payload(jumpBackIn: "[\(postJSON(id: 1))]")))
        XCTAssertFalse(try HomeLayout.showsWelcome(
            payload(friends: #"[{"id": 2, "username": "m", "profile_photo_url": null, "last_posted_at": null}]"#)
        ))
    }

    func test_newRowShowsWheneverTheViewerFollowsSomeone() throws {
        XCTAssertFalse(try HomeLayout.showsNewRow(payload()))
        XCTAssertTrue(try HomeLayout.showsNewRow(
            payload(friends: #"[{"id": 2, "username": "m", "profile_photo_url": null, "last_posted_at": null}]"#)
        ))
    }

    func test_dayKeyUsesTheGivenTimeZone() throws {
        // 2026-10-09 02:00 UTC is still 2026-10-08 in Los Angeles.
        let instant = try XCTUnwrap(ISO8601DateFormatter().date(from: "2026-10-09T02:00:00Z"))
        let la = try XCTUnwrap(TimeZone(identifier: "America/Los_Angeles"))
        XCTAssertEqual(HomeViewModel.dayKey(for: instant, timeZone: la), "2026-10-08")
        XCTAssertEqual(HomeViewModel.dayKey(for: instant, timeZone: .gmt), "2026-10-09")
    }
}
