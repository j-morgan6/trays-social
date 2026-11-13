@testable import TraysSocial
import XCTest

/// W257: the Posted state after publishing. The create response decodes into
/// the new post, the Posted summary builds its share URL and title from it,
/// and a failed create never shows the raw response body.
@MainActor
final class PostedStateTests: XCTestCase {
    /// The body PostController.create/2 renders: PostJSON wrapped in `data`.
    private func createBody(id: Int = 42, caption: String = "Lemon pasta") -> String {
        // JSON-encode the caption so a line break or a quote stays valid JSON.
        let quoted = (try? JSONEncoder().encode(caption)).flatMap { String(data: $0, encoding: .utf8) } ?? #""""#
        return """
        {"data": {"id": \(id), "type": "recipe", "caption": \(quoted), "cooking_time_minutes": 25,
         "servings": 2, "like_count": 0, "comment_count": 0, "liked_by_current_user": false,
         "bookmarked_by_current_user": false, "inserted_at": "2026-11-13T15:00:00Z",
         "user": {"id": 1, "username": "ren", "profile_photo_url": null},
         "photos": [{"url": "/uploads/a.jpg", "thumb_url": null, "medium_url": null, "position": 0}],
         "ingredients": [], "cooking_steps": [], "tools": [], "tags": []}}
        """
    }

    private func post(id: Int, caption: String) throws -> Post {
        try CreatePostViewModel.createdPost(from: Data(createBody(id: id, caption: caption).utf8))
    }

    // MARK: - createdPost(from:)

    func test_createdPostDecodesTheServerCreateBody() throws {
        let post = try CreatePostViewModel.createdPost(from: Data(createBody().utf8))

        XCTAssertEqual(post.id, 42)
        XCTAssertEqual(post.caption, "Lemon pasta")
        XCTAssertEqual(post.cookingTimeMinutes, 25)
        XCTAssertEqual(post.user.username, "ren")
        XCTAssertEqual(post.photos.first?.url, "/uploads/a.jpg")
        XCTAssertEqual(post.insertedAt, ISO8601DateFormatter().date(from: "2026-11-13T15:00:00Z"))
    }

    func test_createdPostThrowsOnABodyWithoutData() {
        let unwrapped = """
        {"id": 42, "type": "recipe", "caption": "Lemon pasta", "like_count": 0, "comment_count": 0,
         "liked_by_current_user": false, "inserted_at": "2026-11-13T15:00:00Z",
         "user": {"id": 1, "username": "ren"}, "photos": [], "ingredients": [],
         "cooking_steps": [], "tools": [], "tags": []}
        """
        for body in [unwrapped, #"{"errors": [{"message": "forbidden"}]}"#, "{}", ""] {
            XCTAssertThrowsError(try CreatePostViewModel.createdPost(from: Data(body.utf8)), body)
        }
    }

    // MARK: - PostedSummary

    func test_postedSummaryBuildsTheShareURLFromTheNewPostID() throws {
        let first = try PostedSummary(post: post(id: 42, caption: "Lemon pasta"), baseURL: "https://trays.example")
        let second = try PostedSummary(post: post(id: 7, caption: "Lemon pasta"), baseURL: "https://trays.example")

        XCTAssertEqual(first.shareURL?.absoluteString, "https://trays.example/p/42")
        XCTAssertEqual(second.shareURL?.absoluteString, "https://trays.example/p/7")
    }

    func test_postedSummaryFallsBackToUntitledRecipeForAnEmptyCaption() throws {
        let empty = try PostedSummary(post: post(id: 5, caption: ""), baseURL: "https://x")
        let blank = try PostedSummary(post: post(id: 6, caption: "   "), baseURL: "https://x")
        let named = try PostedSummary(post: post(id: 8, caption: "Lemon pasta"), baseURL: "https://x")

        XCTAssertEqual(empty.title, "Untitled recipe")
        XCTAssertEqual(blank.title, "Untitled recipe")
        XCTAssertEqual(named.title, "Lemon pasta")
    }

    func test_postedSummaryTitleMatchesTheDetailAndCardTitles() throws {
        for caption in ["Lemon pasta", "Lemon pasta. Bright and quick.", "Dal\nWe make it on Sundays"] {
            let summary = try PostedSummary(post: post(id: 9, caption: caption), baseURL: "https://x")
            // Detail (PostDetailInfo) and the card surfaces (HomeSectionViews) for the same caption.
            XCTAssertEqual(summary.title, RecipeTitle.from(caption: caption, fallback: "Untitled recipe"), caption)
            XCTAssertEqual(summary.title, RecipeTitle.from(caption: caption), caption)
        }
    }

    /// W258: the Posted screen says which collections the recipe went into.
    func test_postedSummaryListsTheCollectionsThePostWasAddedTo() throws {
        let none = try PostedSummary(post: post(id: 3, caption: "Dal"), baseURL: "https://x")
        let one = try PostedSummary(post: post(id: 3, caption: "Dal"), baseURL: "https://x", addedTo: ["Soups"])
        let two = try PostedSummary(post: post(id: 3, caption: "Dal"), baseURL: "https://x", addedTo: ["Weeknights", "Soups"])

        XCTAssertNil(none.addedToLine)
        XCTAssertEqual(one.addedToLine, "Added to Soups")
        let line = try XCTUnwrap(two.addedToLine)
        XCTAssertTrue(line.hasPrefix("Added to "))
        XCTAssertLessThan(try XCTUnwrap(line.range(of: "Weeknights")).lowerBound, try XCTUnwrap(line.range(of: "Soups")).lowerBound)
    }

    // MARK: - handleCreateResponse(data:status:)

    func test_anUndecodableCreatedBodyStillCountsAsPostedWithoutAnError() {
        let viewModel = CreatePostViewModel()
        viewModel.isPublishing = true

        let post = viewModel.handleCreateResponse(data: Data("<html>ok</html>".utf8), status: 201)

        XCTAssertNil(post)
        XCTAssertTrue(viewModel.didPublish)
        XCTAssertNil(viewModel.errorMessage)
        XCTAssertFalse(viewModel.isPublishing)
        XCTAssertEqual(CreatePostViewModel.PublishOutcome(didPublish: viewModel.didPublish, post: post), .closed)
    }

    func test_aDecodableCreatedBodyReturnsTheNewPost() {
        let viewModel = CreatePostViewModel()

        let post = viewModel.handleCreateResponse(data: Data(createBody(id: 42).utf8), status: 201)

        XCTAssertEqual(post?.id, 42)
        XCTAssertTrue(viewModel.didPublish)
        XCTAssertNil(viewModel.errorMessage)
    }

    func test_aRefusedCreateIsNotPostedAndShowsFixedCopy() {
        let viewModel = CreatePostViewModel()
        viewModel.isPublishing = true

        let body = Data(#"{"errors": [{"message": "SECRET_INTERNAL"}]}"#.utf8)
        let post = viewModel.handleCreateResponse(data: body, status: 422)

        XCTAssertNil(post)
        XCTAssertFalse(viewModel.didPublish)
        XCTAssertFalse(viewModel.isPublishing)
        XCTAssertEqual(viewModel.errorMessage, CreatePostViewModel.failureMessage(status: 422, data: Data()))
        XCTAssertEqual(CreatePostViewModel.PublishOutcome(didPublish: viewModel.didPublish, post: post), .failed)
    }

    // MARK: - PublishOutcome

    func test_postCreatedIsPostedOnceForEveryPublishWhereThePostExists() throws {
        let created = try post(id: 42, caption: "Lemon pasta")
        let cases: [(CreatePostViewModel.PublishOutcome, Int)] = [(.posted(created), 1), (.closed, 1), (.failed, 0)]

        for (outcome, expected) in cases {
            let center = NotificationCenter()
            var count = 0
            let token = center.addObserver(forName: .postCreated, object: nil, queue: nil) { _ in count += 1 }
            outcome.announce(on: center)
            center.removeObserver(token)
            XCTAssertEqual(count, expected, "\(outcome)")
        }
    }

    func test_swipeDownIsRefusedOnlyWhilePublishing() {
        let viewModel = CreatePostViewModel()
        XCTAssertTrue(viewModel.allowsInteractiveDismiss)
        viewModel.isPublishing = true
        XCTAssertFalse(viewModel.allowsInteractiveDismiss)
        viewModel.isPublishing = false
        XCTAssertTrue(viewModel.allowsInteractiveDismiss)
    }

    // MARK: - failureMessage(status:data:)

    func test_failureMessageNeverContainsTheRawResponseBody() {
        let bodies = [
            #"{"errors": [{"field": "post_photos", "message": "SECRET_INTERNAL Ecto.Changeset trace"}]}"#,
            "<html>SECRET_INTERNAL stack</html>",
        ]
        let leaks = ["SECRET_INTERNAL", "post_photos", "Ecto", "<html>", "Failed to create post"]

        for body in bodies {
            for status in [0, 400, 401, 403, 404, 413, 422, 429, 500, 502] {
                let message = CreatePostViewModel.failureMessage(status: status, data: Data(body.utf8))
                XCTAssertFalse(message.isEmpty, "status \(status)")
                for leak in leaks {
                    XCTAssertFalse(message.contains(leak), "status \(status) leaked \(leak)")
                }
            }
        }
    }

    func test_uploadErrorsNeverShowServerSuppliedText() {
        let field = FieldError(
            field: "post_photos", message: "SECRET_INTERNAL changeset trace", code: nil, suspendedUntil: nil
        )
        let errors: [Error] = [
            APIError.validationError([field]),
            APIError.conflict(code: "x", message: "SECRET_INTERNAL conflict"),
            APIError.subscriptionRequired(message: "SECRET_INTERNAL plus"),
            APIError.suspended(message: "SECRET_INTERNAL suspended", suspendedUntil: nil),
            APIError.serverError(500),
            APIError.invalidResponse,
            URLError(.notConnectedToInternet),
        ]

        for error in errors {
            let message = CreatePostViewModel.failureMessage(for: error)
            XCTAssertFalse(message.isEmpty, "\(error)")
            XCTAssertFalse(message.contains("SECRET_INTERNAL"), "\(error)")
            XCTAssertFalse(message.contains("post_photos"), "\(error)")
        }
        XCTAssertEqual(
            CreatePostViewModel.failureMessage(for: APIError.serverError(413)),
            CreatePostViewModel.failureMessage(status: 413, data: Data())
        )
    }
}
