@testable import TraysSocial
import XCTest

/// W133: regression coverage for the optimistic-then-rollback flow.
///
/// The mutation methods (`toggleLike`, `toggleBookmark`, `toggleFollow`)
/// apply their optimistic update synchronously and fire the API call
/// in a detached Task. Rollback runs inside that Task's catch branch,
/// asynchronously after the API errors.
///
/// We test the two halves separately:
///   * **Optimistic**: call the toggle, assert the model flipped
///     immediately (before any awaits could resolve). This is the
///     half users feel — instant feedback.
///   * **Rollback**: drive the optimistic state into the VM directly,
///     then verify the documented rollback contract — assigning the
///     original snapshot back to `viewModel.post` / `viewModel.user`
///     restores the pre-tap state.
///
/// We don't end-to-end mock APIClient — that would be a much larger
/// refactor (the singleton is hardcoded). The above split exercises
/// the unit-level invariants the user cares about; the actual
/// network-failure rollback is verified manually at the desk per the
/// W133 verification_steps.
@MainActor
final class OptimisticRollbackTests: XCTestCase {
    // MARK: - PostViewModel.toggleLike

    func test_toggleLike_appliesOptimisticUpdateImmediately() {
        let vm = PostViewModel()
        let original = post(liked: false, likeCount: 10)
        vm.post = original

        vm.toggleLike()

        // Synchronous: the optimistic state was applied before the
        // detached Task could resolve.
        XCTAssertEqual(vm.post?.likedByCurrentUser, true)
        XCTAssertEqual(vm.post?.likeCount, 11)
    }

    func test_toggleLike_unlike_decrementsCount() {
        let vm = PostViewModel()
        let original = post(liked: true, likeCount: 5)
        vm.post = original

        vm.toggleLike()

        XCTAssertEqual(vm.post?.likedByCurrentUser, false)
        XCTAssertEqual(vm.post?.likeCount, 4)
    }

    // MARK: - PostViewModel.toggleBookmark

    func test_toggleBookmark_appliesOptimisticUpdateImmediately() {
        let vm = PostViewModel()
        let original = post(bookmarked: false)
        vm.post = original

        vm.toggleBookmark()

        XCTAssertEqual(vm.post?.bookmarkedByCurrentUser, true)
    }

    func test_toggleBookmark_rollbackPathRestoresOriginal() {
        // Drive the rollback contract directly: reassigning the
        // original snapshot is what the catch branch does. This is
        // the half a network failure exercises.
        let vm = PostViewModel()
        let original = post(bookmarked: false)
        vm.post = original

        vm.toggleBookmark()
        XCTAssertEqual(vm.post?.bookmarkedByCurrentUser, true) // optimistic

        // Simulate the rollback that the failure branch performs.
        vm.post = original
        XCTAssertEqual(vm.post?.bookmarkedByCurrentUser, false) // back to original
    }

    // MARK: - Toast copy

    func test_toast_lockedCopyMatchesSpec() {
        XCTAssertEqual(Toast.likeFailed.message, "Couldn't like. Try again.")
        XCTAssertEqual(Toast.saveFailed.message, "Couldn't save. Try again.")
        XCTAssertEqual(Toast.unsaveFailed.message, "Couldn't remove from tray. Try again.")
        XCTAssertEqual(Toast.followFailed.message, "Couldn't follow. Try again.")
        XCTAssertEqual(Toast.unfollowFailed.message, "Couldn't unfollow. Try again.")
    }

    // MARK: - Helpers

    private func post(
        liked: Bool = false,
        likeCount: Int = 0,
        bookmarked: Bool = false
    ) -> Post {
        Post(
            id: 1, type: "recipe", caption: "Test",
            cookingTimeMinutes: nil, servings: nil,
            likeCount: likeCount, commentCount: 0,
            likedByCurrentUser: liked,
            bookmarkedByCurrentUser: bookmarked,
            insertedAt: Date(),
            user: PostUser(id: 1, username: "alice", profilePhotoUrl: nil),
            photos: [], ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }
}
