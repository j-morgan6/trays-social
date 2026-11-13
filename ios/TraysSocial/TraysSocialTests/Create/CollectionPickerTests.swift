@testable import TraysSocial
import XCTest

/// W258: the recipe editor's Add to a collection card. Pure state tests, like
/// CollectionsViewModelTests: the selection, when the card shows, and the
/// follow-up adds after publishing, driven through an injected add call
/// because APIClient has no mock seam.
@MainActor
final class CollectionPickerTests: XCTestCase {
    // MARK: - Selection

    func test_togglingSelectsAndDeselectsInTapOrder() {
        let collections = [Self.collection(id: 1, name: "A"), Self.collection(id: 2, name: "B"), Self.collection(id: 3, name: "C")]
        var state = CollectionPickerState()

        state.toggle(3)
        state.toggle(1)
        state.toggle(2)
        XCTAssertEqual(state.selectedIDs, [3, 1, 2])
        XCTAssertEqual(state.followUpPlan(from: collections).map(\.name), ["C", "A", "B"])

        state.toggle(1)
        XCTAssertEqual(state.selectedIDs, [3, 2])
        XCTAssertFalse(state.isSelected(1))

        state.toggle(1)
        XCTAssertEqual(state.selectedIDs, [3, 2, 1], "a re-selected collection goes to the end")
        XCTAssertTrue(state.isSelected(1))
    }

    func test_noSelectionMeansNoFollowUpAdds() async {
        let state = CollectionPickerState()
        let plan = state.followUpPlan(from: [Self.collection(id: 1, name: "A")])
        var calls: [Int] = []

        let result = await CollectionAddResult.run(plan, postID: 42) { collectionID, _ in
            calls.append(collectionID)
        }

        XCTAssertTrue(plan.isEmpty)
        XCTAssertEqual(calls, [])
        XCTAssertEqual(result, .none)
        XCTAssertNil(result.failureToastMessage)
    }

    func test_aFailedAddIsReportedByNameAndTheOthersStillCount() async throws {
        let plan = [
            CollectionAddTarget(id: 1, name: "Weeknights"),
            CollectionAddTarget(id: 2, name: "Soups"),
            CollectionAddTarget(id: 3, name: "Date night"),
            CollectionAddTarget(id: 4, name: "Lapsed"),
            CollectionAddTarget(id: -1, name: "Still creating"),
        ]
        var calls: [[Int]] = []

        let result = await CollectionAddResult.run(plan, postID: 42) { collectionID, postID in
            calls.append([collectionID, postID])
            switch collectionID {
            case 2: throw APIError.notFound
            case 4: throw APIError.subscriptionRequired(message: "Trays Plus required")
            default: return
            }
        }

        XCTAssertEqual(calls, [[1, 42], [2, 42], [3, 42], [4, 42]], "a pending collection sends no request")
        XCTAssertEqual(result.added, ["Weeknights", "Date night"])
        XCTAssertEqual(result.failed, ["Soups", "Lapsed", "Still creating"])
        let message = try XCTUnwrap(result.failureToastMessage)
        XCTAssertTrue(message.contains("Soups"))
        XCTAssertTrue(message.contains("Lapsed"))
        XCTAssertTrue(message.contains("Still creating"))
        XCTAssertFalse(message.contains("Weeknights"))
        XCTAssertFalse(message.contains("Date night"))
    }

    // MARK: - Visibility

    func test_theCardIsHiddenWhenCollectionsFailedToLoad() {
        XCTAssertEqual(CollectionPickerState.visibility(isPlus: true, loadState: .failed), .hidden)
        XCTAssertEqual(CollectionPickerState.visibility(isPlus: true, loadState: .idle), .hidden)
        XCTAssertEqual(CollectionPickerState.visibility(isPlus: true, loadState: .loading), .hidden)
        XCTAssertEqual(CollectionPickerState.visibility(isPlus: true, loadState: .loaded), .shown)
        XCTAssertEqual(CollectionsViewModel().loadState, .idle, "nothing loads until the editor asks")
    }

    func test_theCardIsHiddenForNonPlusUsers() {
        for loadState in [CollectionsLoadState.idle, .loading, .loaded, .failed] {
            XCTAssertEqual(CollectionPickerState.visibility(isPlus: false, loadState: loadState), .hidden, "\(loadState)")
        }
    }

    // MARK: - Keeping the selection honest

    func test_aCollectionRemovedAfterLoadIsDroppedFromTheSelection() {
        let weeknights = Self.collection(id: 1, name: "Weeknights")
        var state = CollectionPickerState()
        state.toggle(2)
        state.toggle(1)

        state.sync(with: [weeknights], confirmed: [:])

        XCTAssertEqual(state.selectedIDs, [1])
        XCTAssertEqual(state.followUpPlan(from: [weeknights]), [CollectionAddTarget(id: 1, name: "Weeknights")])
    }

    func test_aNewCollectionIsSelectedOnCreate() throws {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, name: "Soups")]
        var state = CollectionPickerState()

        let pendingID = try XCTUnwrap(viewModel.beginCreate(name: "Weeknights").pendingID)
        state.selectNew(pendingID)
        state.selectNew(pendingID)
        XCTAssertEqual(state.selectedIDs, [pendingID], "selecting a new collection twice never deselects it")
        XCTAssertEqual(state.followUpPlan(from: viewModel.collections).map(\.name), ["Weeknights"])

        viewModel.confirmCreate(pendingID: pendingID, with: Self.collection(id: 99, name: "Weeknights"))
        state.sync(with: viewModel.collections, confirmed: viewModel.confirmedIDs)
        XCTAssertEqual(state.selectedIDs, [99], "the selection follows the pending row to its server id")
        XCTAssertEqual(state.followUpPlan(from: viewModel.collections), [CollectionAddTarget(id: 99, name: "Weeknights")])

        let rolledBack = try XCTUnwrap(viewModel.beginCreate(name: "Desserts").pendingID)
        state.selectNew(rolledBack)
        viewModel.rollbackCreate(pendingID: rolledBack)
        state.sync(with: viewModel.collections, confirmed: viewModel.confirmedIDs)
        XCTAssertEqual(state.selectedIDs, [99], "a create that rolled back drops out")
    }

    // MARK: - After publishing

    func test_postCreatedIsAnnouncedOnlyAfterTheCollectionAddsSettle() async throws {
        let viewModel = CreatePostViewModel()
        viewModel.collections.collections = [Self.collection(id: 1, name: "Weeknights"), Self.collection(id: 2, name: "Soups")]
        viewModel.collectionPicker.toggle(2)
        viewModel.collectionPicker.toggle(1)
        let center = NotificationCenter()
        var events: [String] = []
        let token = center.addObserver(forName: .postCreated, object: nil, queue: nil) { _ in events.append("announce") }
        defer { center.removeObserver(token) }

        let result = try await viewModel.settlePublish(
            .posted(Self.post(id: 42)), filesIntoCollections: true, center: center
        ) { collectionID, postID in
            events.append("add \(collectionID) busy=\(viewModel.isBusy)")
            XCTAssertEqual(postID, 42)
        }

        XCTAssertEqual(events, ["add 2 busy=true", "add 1 busy=true", "announce"])
        XCTAssertEqual(result.added, ["Soups", "Weeknights"])
        XCTAssertFalse(viewModel.isBusy, "Post and swipe-down come back once the adds are done")
    }

    func test_aFailedPublishFilesNothingAndAnnouncesNothing() async {
        let viewModel = CreatePostViewModel()
        viewModel.collections.collections = [Self.collection(id: 1, name: "Weeknights")]
        viewModel.collectionPicker.toggle(1)
        let center = NotificationCenter()
        var events: [String] = []
        let token = center.addObserver(forName: .postCreated, object: nil, queue: nil) { _ in events.append("announce") }
        defer { center.removeObserver(token) }

        let result = await viewModel.settlePublish(.failed, filesIntoCollections: true, center: center) { collectionID, _ in
            events.append("add \(collectionID)")
        }

        XCTAssertEqual(events, [])
        XCTAssertEqual(result, .none)
    }

    func test_aCollectionMadeJustBeforePostingIsFiledOnceItsCreateConfirms() async throws {
        let viewModel = CreatePostViewModel()
        let pendingID = try XCTUnwrap(viewModel.collections.beginCreate(name: "Weeknights").pendingID)
        viewModel.collectionPicker.selectNew(pendingID)
        var calls: [Int] = []

        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(150))
            viewModel.collections.confirmCreate(pendingID: pendingID, with: Self.collection(id: 99, name: "Weeknights"))
        }
        let result = try await viewModel.fileIntoSelectedCollections(post: Self.post(id: 42), enabled: true) { collectionID, _ in
            calls.append(collectionID)
        }

        XCTAssertEqual(calls, [99], "the pending id is never sent; the confirmed one is")
        XCTAssertEqual(result.added, ["Weeknights"])
        XCTAssertNil(result.failureToastMessage)
    }

    // MARK: - Fixtures

    /// A post decoded from the create body, as PostedStateTests builds one.
    private static func post(id: Int) throws -> Post {
        let body = """
        {"data": {"id": \(id), "type": "recipe", "caption": "Dal", "like_count": 0, "comment_count": 0,
         "liked_by_current_user": false, "inserted_at": "2026-11-13T15:00:00Z",
         "user": {"id": 1, "username": "ren"}, "photos": [], "ingredients": [],
         "cooking_steps": [], "tools": [], "tags": []}}
        """
        return try CreatePostViewModel.createdPost(from: Data(body.utf8))
    }

    /// Mirrors the private `collection(...)` helper in CollectionsViewModelTests.
    private static func collection(id: Int, name: String = "Collection", itemCount: Int = 0) -> RecipeCollection {
        RecipeCollection(id: id, name: name, itemCount: itemCount, coverPhotoUrl: nil, insertedAt: Date())
    }
}
