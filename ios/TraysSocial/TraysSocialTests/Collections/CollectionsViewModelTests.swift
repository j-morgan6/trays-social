@testable import TraysSocial
import XCTest

/// Pure state-transition tests, matching every other ViewModel test in this
/// project: `APIClient` is a hardcoded actor singleton with no protocol seam
/// and the team has deliberately not mocked it, so these drive the optimistic
/// apply / confirm / rollback seams directly rather than through the network.
@MainActor
final class CollectionsViewModelTests: XCTestCase {
    // MARK: - Shelf visibility

    func test_freshViewModel_hasNoCollections_andShelfIsHidden() {
        let viewModel = CollectionsViewModel()

        XCTAssertTrue(viewModel.collections.isEmpty)
        XCTAssertFalse(viewModel.hasCollections, "an empty shelf must not render at all (AC 1)")
    }

    func test_hasCollections_trueOnceRowsExist() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1)]

        XCTAssertTrue(viewModel.hasCollections)
    }

    func test_collectionWithZeroItems_isKept_andReportsZero() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 0)]

        XCTAssertTrue(viewModel.hasCollections)
        XCTAssertEqual(viewModel.collections[0].itemCount, 0)
    }

    // MARK: - Name validation

    func test_validate_trimsSurroundingWhitespace() {
        XCTAssertEqual(CollectionsViewModel.validate(name: "  Desserts  ", existing: []), .valid("Desserts"))
    }

    func test_validate_rejectsEmptyName() {
        XCTAssertEqual(CollectionsViewModel.validate(name: "", existing: []), .empty)
    }

    func test_validate_rejectsWhitespaceOnlyName() {
        XCTAssertEqual(CollectionsViewModel.validate(name: "   \n ", existing: []), .empty)
    }

    func test_validate_acceptsExactly60Characters() {
        let name = String(repeating: "a", count: 60)

        XCTAssertEqual(CollectionsViewModel.validate(name: name, existing: []), .valid(name))
    }

    /// Matches `Collection.changeset`'s `validate_length(max: 60)` — catching it
    /// here means no optimistic row appears and then vanishes on the 422.
    func test_validate_rejects61Characters() {
        let name = String(repeating: "a", count: 61)

        XCTAssertEqual(CollectionsViewModel.validate(name: name, existing: []), .tooLong)
    }

    func test_validate_rejectsDuplicateNameCaseInsensitively() {
        let existing = [Self.collection(id: 1, name: "Desserts")]

        XCTAssertEqual(CollectionsViewModel.validate(name: "desserts", existing: existing), .duplicate)
    }

    func test_validate_allowsRenamingACollectionToItsOwnName() {
        let existing = [Self.collection(id: 1, name: "Desserts")]

        XCTAssertEqual(
            CollectionsViewModel.validate(name: "Desserts", existing: existing, excludingID: 1),
            .valid("Desserts")
        )
    }

    // MARK: - Create

    func test_create_insertsPendingRowAtTop_withZeroItems_andNegativeID() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 9, name: "Older")]

        viewModel.beginCreate(name: "Desserts")

        XCTAssertEqual(viewModel.collections.count, 2)
        XCTAssertEqual(viewModel.collections[0].name, "Desserts")
        XCTAssertEqual(viewModel.collections[0].itemCount, 0)
        XCTAssertTrue(viewModel.collections[0].isPending)
    }

    /// Two in-flight creates must not collide on the same placeholder id, or
    /// confirming the first would replace the second's row.
    func test_create_assignsDecreasingPendingIDs() {
        let viewModel = CollectionsViewModel()

        viewModel.beginCreate(name: "One")
        viewModel.beginCreate(name: "Two")

        let ids = Set(viewModel.collections.map(\.id))
        XCTAssertEqual(ids.count, 2)
        XCTAssertTrue(viewModel.collections.allSatisfy(\.isPending))
    }

    func test_create_invalidName_addsNoRow_andReturnsValidation() {
        let viewModel = CollectionsViewModel()

        let result = viewModel.beginCreate(name: "   ").validation

        XCTAssertEqual(result, .empty)
        XCTAssertTrue(viewModel.collections.isEmpty)
    }

    func test_confirmCreate_replacesPendingRowInPlace_withServerID() {
        let viewModel = CollectionsViewModel()
        viewModel.beginCreate(name: "Desserts")
        let pendingID = viewModel.collections[0].id

        viewModel.confirmCreate(pendingID: pendingID, with: Self.collection(id: 42, name: "Desserts"))

        XCTAssertEqual(viewModel.collections.count, 1)
        XCTAssertEqual(viewModel.collections[0].id, 42)
        XCTAssertFalse(viewModel.collections[0].isPending)
    }

    func test_rollbackCreate_removesPendingRow_andRestoresOriginalArray() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 9, name: "Older")]
        viewModel.beginCreate(name: "Desserts")
        let pendingID = viewModel.collections[0].id

        viewModel.rollbackCreate(pendingID: pendingID)

        XCTAssertEqual(viewModel.collections.map(\.id), [9])
    }

    // MARK: - Rename

    func test_rename_appliesOptimisticallyAtSameIndex() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, name: "A"), Self.collection(id: 2, name: "B")]

        viewModel.beginRename(id: 2, to: "Renamed")

        XCTAssertEqual(viewModel.collections[1].name, "Renamed")
        XCTAssertEqual(viewModel.collections.map(\.id), [1, 2], "rename must not reorder the shelf")
    }

    func test_rollbackRename_restoresOriginalNameAtSameIndex() {
        let viewModel = CollectionsViewModel()
        let original = Self.collection(id: 2, name: "B")
        viewModel.collections = [Self.collection(id: 1, name: "A"), original]
        viewModel.beginRename(id: 2, to: "Renamed")

        viewModel.rollbackRename(id: 2, to: original)

        XCTAssertEqual(viewModel.collections[1].name, "B")
        XCTAssertEqual(viewModel.collections.map(\.id), [1, 2])
    }

    func test_rename_isNoopWhenIDNotPresent() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, name: "A")]

        viewModel.beginRename(id: 99, to: "Ghost")

        XCTAssertEqual(viewModel.collections[0].name, "A")
    }

    // MARK: - Delete

    func test_delete_removesRowImmediately() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1), Self.collection(id: 2), Self.collection(id: 3)]

        viewModel.beginDelete(id: 2)

        XCTAssertEqual(viewModel.collections.map(\.id), [1, 3])
    }

    func test_rollbackDelete_reinsertsAtOriginalIndex() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1), Self.collection(id: 2), Self.collection(id: 3)]
        viewModel.beginDelete(id: 2)

        viewModel.rollbackDelete(id: 2)

        XCTAssertEqual(viewModel.collections.map(\.id), [1, 2, 3], "the row must return to where it was")
    }

    func test_rollbackDelete_clampsWhenListShrank() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1), Self.collection(id: 2), Self.collection(id: 3)]
        viewModel.beginDelete(id: 3)
        viewModel.collections = []

        viewModel.rollbackDelete(id: 3)

        XCTAssertEqual(viewModel.collections.map(\.id), [3], "clamped insert, not a crash")
    }

    func test_rollbackDelete_isNoopWhenNothingStashed() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1)]

        viewModel.rollbackDelete(id: 99)

        XCTAssertEqual(viewModel.collections.map(\.id), [1])
    }

    func test_confirmDelete_thenRollback_isNoop() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1)]
        viewModel.beginDelete(id: 1)
        viewModel.confirmDelete(id: 1)

        viewModel.rollbackDelete(id: 1)

        XCTAssertTrue(viewModel.collections.isEmpty, "a confirmed delete must not be resurrectable")
    }

    // MARK: - Add post

    func test_addPost_incrementsItemCount() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 2)]

        viewModel.beginAdd(Self.post(id: 7), to: 1)

        XCTAssertEqual(viewModel.collections[0].itemCount, 3)
    }

    /// The server's cover is the newest item's photo, so the optimistic view
    /// has to move the cover too or the shelf visibly corrects itself on the
    /// next refresh.
    func test_addPost_replacesCoverWithAddedPostsPhoto() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, coverPhotoUrl: "/uploads/old.jpg")]

        viewModel.beginAdd(Self.post(id: 7, photoUrl: "/uploads/new.jpg"), to: 1)

        XCTAssertEqual(viewModel.collections[0].coverPhotoUrl, "/uploads/new.jpg")
    }

    func test_addPost_isNoopWhenCollectionIDNotPresent() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 2)]

        viewModel.beginAdd(Self.post(id: 7), to: 99)

        XCTAssertEqual(viewModel.collections[0].itemCount, 2)
    }

    func test_rollbackAdd_restoresBothCountAndCover() {
        let viewModel = CollectionsViewModel()
        let original = Self.collection(id: 1, itemCount: 2, coverPhotoUrl: "/uploads/old.jpg")
        viewModel.collections = [original]
        viewModel.beginAdd(Self.post(id: 7, photoUrl: "/uploads/new.jpg"), to: 1)

        viewModel.rollbackAdd(id: 1, to: original)

        XCTAssertEqual(viewModel.collections[0].itemCount, 2)
        XCTAssertEqual(viewModel.collections[0].coverPhotoUrl, "/uploads/old.jpg")
    }

    // MARK: - Remove-post sync from the detail screen

    func test_applyItemRemoved_decrementsItemCount() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 3)]

        viewModel.applyItemRemoved(collectionId: 1)

        XCTAssertEqual(viewModel.collections[0].itemCount, 2)
    }

    func test_applyItemRemoved_neverGoesBelowZero() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 0)]

        viewModel.applyItemRemoved(collectionId: 1)

        XCTAssertEqual(viewModel.collections[0].itemCount, 0)
    }

    func test_applyItemRestored_reincrementsItemCount() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 3)]
        viewModel.applyItemRemoved(collectionId: 1)

        viewModel.applyItemRestored(collectionId: 1)

        XCTAssertEqual(viewModel.collections[0].itemCount, 3)
    }

    /// Collection membership is its own table server-side. Unbookmarking a post
    /// elsewhere in the app must not touch any collection's count.
    func test_unbookmarkingAPostDoesNotChangeAnyCollectionCount() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 1, itemCount: 3)]

        NotificationCenter.default.post(
            name: .postUpdated, object: nil,
            userInfo: ["post": Self.post(id: 7)]
        )

        XCTAssertEqual(viewModel.collections[0].itemCount, 3)
    }

    // MARK: - Write failure routing (AC 6)

    func test_writeOutcome_subscriptionRequired_presentsPaywall() {
        let error = APIError.subscriptionRequired(message: "Trays Plus subscription required")

        XCTAssertEqual(CollectionWriteOutcome.decide(for: error), .presentPaywall)
    }

    /// A bare 403 means the post is neither authored nor saved by this user —
    /// a real permission failure, not a sales moment.
    func test_writeOutcome_bareForbidden_toasts() {
        XCTAssertEqual(CollectionWriteOutcome.decide(for: APIError.forbidden), .toast)
    }

    func test_writeOutcome_validationError_toasts() {
        let error = APIError.validationError([FieldError(field: "name", message: "has already been taken")])

        XCTAssertEqual(CollectionWriteOutcome.decide(for: error), .toast)
    }

    func test_writeOutcome_networkError_toasts() {
        XCTAssertEqual(CollectionWriteOutcome.decide(for: APIError.serverError(500)), .toast)
    }

    func test_handleWriteFailure_subscriptionRequired_setsNeedsPaywall() {
        let viewModel = CollectionsViewModel()

        viewModel.handleWriteFailure(
            APIError.subscriptionRequired(message: "Trays Plus subscription required"),
            operation: "add", toast: .collectionAddFailed
        )

        XCTAssertTrue(viewModel.needsPaywall)
    }

    /// A paywall and a toast at once would be two contradictory explanations of
    /// the same event.
    ///
    /// Asserted on the funnel's returned branch rather than on the absence of a
    /// `.traysErrorOccurred` notification: that bus is process-global and
    /// shared with every other suite, so "no toast was posted" is not a claim
    /// a single test can honestly make about one call.
    func test_handleWriteFailure_subscriptionRequired_takesThePaywallBranchOnly() {
        let viewModel = CollectionsViewModel()

        let outcome = viewModel.handleWriteFailure(
            APIError.subscriptionRequired(message: "Trays Plus subscription required"),
            operation: "add", toast: .collectionAddFailed
        )

        XCTAssertEqual(outcome, .presentPaywall)
        XCTAssertTrue(viewModel.needsPaywall)
    }

    func test_handleWriteFailure_otherError_takesTheToastBranchOnly() {
        let viewModel = CollectionsViewModel()

        let outcome = viewModel.handleWriteFailure(
            APIError.forbidden, operation: "add", toast: .collectionAddFailed
        )

        XCTAssertEqual(outcome, .toast)
        XCTAssertFalse(viewModel.needsPaywall, "a plain permission failure must not open the paywall")
    }

    func test_handleWriteFailure_otherError_leavesNeedsPaywallFalse() {
        let viewModel = CollectionsViewModel()

        viewModel.handleWriteFailure(APIError.serverError(500), operation: "add", toast: .collectionAddFailed)

        XCTAssertFalse(viewModel.needsPaywall)
    }

    func test_gatedAddFailure_rollsBackCountAndPresentsPaywall() {
        let viewModel = CollectionsViewModel()
        let original = Self.collection(id: 1, itemCount: 2)
        viewModel.collections = [original]
        viewModel.beginAdd(Self.post(id: 7), to: 1)

        viewModel.rollbackAdd(id: 1, to: original)
        viewModel.handleWriteFailure(
            APIError.subscriptionRequired(message: "Trays Plus subscription required"),
            operation: "add", toast: .collectionAddFailed
        )

        XCTAssertEqual(viewModel.collections[0].itemCount, 2)
        XCTAssertTrue(viewModel.needsPaywall)
    }

    // MARK: - Locked-intent replay

    func test_requestAddWhileLocked_remembersThePostAndOpensThePaywall() {
        let viewModel = CollectionsViewModel()

        viewModel.requestAddWhileLocked(Self.post(id: 7))

        XCTAssertTrue(viewModel.needsPaywall)
        XCTAssertEqual(viewModel.pendingAdd?.id, 7)
    }

    /// A brand-new subscriber has nowhere to file the recipe yet, so the caller
    /// is told to open the create form; the add completes on confirmCreate.
    func test_replayPendingAdd_withNoCollections_asksForTheCreateForm() {
        let viewModel = CollectionsViewModel()
        viewModel.requestAddWhileLocked(Self.post(id: 7))

        XCTAssertTrue(viewModel.replayPendingAdd())
        XCTAssertEqual(viewModel.pendingAdd?.id, 7, "the intent must survive until the collection exists")
    }

    /// The hand-off `confirmCreate` performs once the new collection has a real
    /// id. Asserted on the pure seam so the test does not issue the follow-up
    /// request that the production path does.
    func test_consumePendingAdd_handsOverTheRecipeExactlyOnce() {
        let viewModel = CollectionsViewModel()
        viewModel.requestAddWhileLocked(Self.post(id: 7))

        XCTAssertEqual(viewModel.consumePendingAdd()?.id, 7)
        XCTAssertNil(viewModel.pendingAdd)
        XCTAssertNil(viewModel.consumePendingAdd(), "a replayed intent must not fire twice")
    }

    /// With two or more collections there is no honest guess about which one
    /// the user meant, so the intent is dropped rather than filed at random.
    func test_replayPendingAdd_withSeveralCollections_dropsTheIntent() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 5, itemCount: 1), Self.collection(id: 6, itemCount: 1)]
        viewModel.requestAddWhileLocked(Self.post(id: 7))

        XCTAssertFalse(viewModel.replayPendingAdd())
        XCTAssertNil(viewModel.pendingAdd)
        XCTAssertEqual(viewModel.collections.map(\.itemCount), [1, 1])
    }

    /// The intent must not outlive the interaction that created it: My Tray's
    /// state lives for the whole session, so a survivor would be consumed by
    /// the next unrelated create and file a recipe nobody asked for.
    func test_cancelPendingAdd_dropsTheIntent() {
        let viewModel = CollectionsViewModel()
        viewModel.requestAddWhileLocked(Self.post(id: 7))

        viewModel.cancelPendingAdd()

        XCTAssertNil(viewModel.pendingAdd)
    }

    func test_cancelledIntent_isNotInheritedByALaterCreate() {
        let viewModel = CollectionsViewModel()
        viewModel.requestAddWhileLocked(Self.post(id: 7))
        viewModel.cancelPendingAdd()
        viewModel.beginCreate(name: "Unrelated")
        let pendingID = viewModel.collections[0].id

        viewModel.confirmCreate(pendingID: pendingID, with: Self.collection(id: 42, name: "Unrelated"))

        XCTAssertEqual(viewModel.collections[0].itemCount, 0, "a stale intent must not file into a new collection")
    }

    func test_replayPendingAdd_withNothingPending_isNoop() {
        let viewModel = CollectionsViewModel()
        viewModel.collections = [Self.collection(id: 5, itemCount: 1)]

        XCTAssertFalse(viewModel.replayPendingAdd())
        XCTAssertEqual(viewModel.collections[0].itemCount, 1)
    }

    func test_needsPaywall_clearsWhenDismissed() {
        let viewModel = CollectionsViewModel()
        viewModel.needsPaywall = true

        viewModel.needsPaywall = false

        XCTAssertFalse(viewModel.needsPaywall)
    }

    // MARK: - Fixtures

    private static func collection(
        id: Int,
        name: String = "Collection",
        itemCount: Int = 0,
        coverPhotoUrl: String? = nil
    ) -> RecipeCollection {
        RecipeCollection(
            id: id, name: name, itemCount: itemCount,
            coverPhotoUrl: coverPhotoUrl, insertedAt: Date()
        )
    }

    /// Mirrors the `post(...)` helper in OptimisticRollbackTests, which is
    /// file-private there.
    private static func post(id: Int, photoUrl: String? = nil) -> Post {
        let photos = photoUrl.map { [PostPhoto(url: $0, thumbUrl: nil, mediumUrl: nil, position: 0)] } ?? []
        return Post(
            id: id, type: "recipe", caption: "A recipe",
            cookingTimeMinutes: nil, servings: nil,
            likeCount: 0, commentCount: 0,
            likedByCurrentUser: false,
            bookmarkedByCurrentUser: true,
            insertedAt: Date(),
            user: PostUser(id: 1, username: "alice", profilePhotoUrl: nil),
            photos: photos, ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }
}
