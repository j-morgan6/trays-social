@testable import TraysSocial
import XCTest

/// Pure state-transition tests for the collection detail screen: pagination
/// bookkeeping, the stale-page guard, and remove/rollback. Same no-network
/// approach as every other ViewModel test here.
@MainActor
final class CollectionDetailViewModelTests: XCTestCase {
    // MARK: - Pagination bookkeeping

    func test_isEmpty_trueForCollectionWithZeroItems() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)

        XCTAssertTrue(viewModel.isEmpty)
    }

    func test_applyPage_setsHasMoreTrueWhenCursorPresent() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)

        viewModel.applyPage(
            [Self.post(id: 1)], cursor: "abc", generation: viewModel.currentGeneration
        )

        XCTAssertTrue(viewModel.hasMore)
        XCTAssertEqual(viewModel.cursor, "abc")
    }

    func test_applyPage_setsHasMoreFalseWhenCursorNil() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)

        viewModel.applyPage([Self.post(id: 1)], cursor: nil, generation: viewModel.currentGeneration)

        XCTAssertFalse(viewModel.hasMore)
        XCTAssertNil(viewModel.cursor)
    }

    func test_loadMore_isNoopWhenCursorIsNil() async {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]
        viewModel.cursor = nil

        await viewModel.loadMore()

        XCTAssertEqual(viewModel.posts.count, 1)
        XCTAssertFalse(viewModel.isLoadingMore)
    }

    func test_loadMore_isNoopWhenHasMoreIsFalse() async {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]
        viewModel.cursor = "abc"
        viewModel.hasMore = false

        await viewModel.loadMore()

        XCTAssertEqual(viewModel.posts.count, 1)
    }

    /// A page that was in flight when the user pulled to refresh must be
    /// dropped, not appended onto the fresh page 1 — appending would also
    /// clobber the new cursor.
    func test_stalePage_isDiscardedAfterRefresh() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]
        let staleGeneration = viewModel.currentGeneration
        viewModel.bumpGenerationForTesting()

        viewModel.applyPage([Self.post(id: 99)], cursor: "stale", generation: staleGeneration)

        XCTAssertEqual(viewModel.posts.map(\.id), [1])
        XCTAssertNil(viewModel.cursor)
    }

    func test_freshPage_isAppendedAfterRefresh() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]
        viewModel.bumpGenerationForTesting()

        viewModel.applyPage(
            [Self.post(id: 2)], cursor: "next", generation: viewModel.currentGeneration
        )

        XCTAssertEqual(viewModel.posts.map(\.id), [1, 2])
    }

    // MARK: - Remove from collection

    func test_removePost_dropsCardImmediately() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1), Self.post(id: 2), Self.post(id: 3)]

        viewModel.beginRemove(Self.post(id: 2))

        XCTAssertEqual(viewModel.posts.map(\.id), [1, 3])
    }

    /// The shelf's item count lives on a different ViewModel on a screen that
    /// never unmounts, so this notification is load-bearing, not a nicety.
    func test_removePost_broadcastsSoTheShelfCanDecrement() {
        let viewModel = CollectionDetailViewModel(collectionID: 7)
        viewModel.posts = [Self.post(id: 1)]
        let broadcast = expectation(forNotification: .collectionItemRemoved, object: nil) { note in
            (note.userInfo?["collectionId"] as? Int) == 7
        }

        viewModel.beginRemove(Self.post(id: 1))

        wait(for: [broadcast], timeout: 1.0)
    }

    func test_rollbackRemove_reinsertsAtOriginalIndex() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1), Self.post(id: 2), Self.post(id: 3)]
        viewModel.beginRemove(Self.post(id: 2))

        viewModel.rollbackRemove(postId: 2)

        XCTAssertEqual(viewModel.posts.map(\.id), [1, 2, 3])
    }

    func test_rollbackRemove_clampsWhenListShrank() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1), Self.post(id: 2)]
        viewModel.beginRemove(Self.post(id: 2))
        viewModel.posts = []

        viewModel.rollbackRemove(postId: 2)

        XCTAssertEqual(viewModel.posts.map(\.id), [2])
    }

    func test_rollbackRemove_isNoopWhenNothingStashed() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]

        viewModel.rollbackRemove(postId: 99)

        XCTAssertEqual(viewModel.posts.map(\.id), [1])
    }

    func test_confirmRemove_thenRollback_isNoop() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]
        viewModel.beginRemove(Self.post(id: 1))
        viewModel.confirmRemove(postId: 1)

        viewModel.rollbackRemove(postId: 1)

        XCTAssertTrue(viewModel.posts.isEmpty)
    }

    // MARK: - Cross-screen sync

    /// The key divergence from `MyTrayViewModel.applyPostUpdate`: collection
    /// membership is its own table, so unbookmarking a post elsewhere must NOT
    /// evict it from the collection — the server would still return it.
    func test_applyPostUpdate_unbookmarkedPostStaysInTheCollection() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1, bookmarked: true)]

        viewModel.applyPostUpdate(Self.post(id: 1, bookmarked: false))

        XCTAssertEqual(viewModel.posts.map(\.id), [1])
        XCTAssertEqual(viewModel.posts[0].bookmarkedByCurrentUser, false)
    }

    func test_applyPostUpdate_isNoopForAPostNotOnThisPage() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1)]

        viewModel.applyPostUpdate(Self.post(id: 99))

        XCTAssertEqual(viewModel.posts.map(\.id), [1])
    }

    func test_removePostByID_dropsAnOwnerDeletedPost() {
        let viewModel = CollectionDetailViewModel(collectionID: 1)
        viewModel.posts = [Self.post(id: 1), Self.post(id: 2)]

        viewModel.removePost(id: 2)

        XCTAssertEqual(viewModel.posts.map(\.id), [1])
    }

    // MARK: - Fixtures

    private static func post(id: Int, bookmarked: Bool = true) -> Post {
        Post(
            id: id, type: "recipe", caption: "A recipe",
            cookingTimeMinutes: nil, servings: nil,
            likeCount: 0, commentCount: 0,
            likedByCurrentUser: false,
            bookmarkedByCurrentUser: bookmarked,
            insertedAt: Date(),
            user: PostUser(id: 1, username: "alice", profilePhotoUrl: nil),
            photos: [], ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }
}
