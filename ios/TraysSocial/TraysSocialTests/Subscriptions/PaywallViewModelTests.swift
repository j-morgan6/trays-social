import StoreKit
@testable import TraysSocial
import XCTest

// MARK: - Fakes

/// File-scope, not nested: swiftlint's `nesting` rule forbids more than one
/// level, and `SubscriptionServiceTests` established this shape in W175.
private final class SpyPurchasing: PaywallPurchasing {
    enum Call: Equatable {
        case load
        case purchase(String)
        case restore
    }

    var calls: [Call] = []

    var plansToReturn: [PlanOption] = []
    var plansByCall: [[PlanOption]] = []
    var outcomeToReturn: SubscriptionService.PurchaseOutcome = .completed
    var purchaseError: Error?
    var restoreError: Error?
    /// What the App Store surfaced. Defaults to "nothing", so a test that says
    /// nothing about entitlements gets the empty-Apple-ID case.
    var restoreOutcomeToReturn: SubscriptionService.RestoreOutcome = .noEntitlements

    /// Fires inside `purchase`/`restore`, before they return — the hook that
    /// simulates the server entitlement refresh landing. Same trick as
    /// `SpyBackend.onVerify` in the W175 tests.
    var onPurchase: (() -> Void)?
    var onRestore: (() -> Void)?

    func loadPlans() async -> [PlanOption] {
        calls.append(.load)
        if !plansByCall.isEmpty {
            return plansByCall.removeFirst()
        }
        return plansToReturn
    }

    func purchase(planID: String) async throws -> SubscriptionService.PurchaseOutcome {
        calls.append(.purchase(planID))
        onPurchase?()
        if let purchaseError {
            throw purchaseError
        }
        return outcomeToReturn
    }

    func restore() async throws -> SubscriptionService.RestoreOutcome {
        calls.append(.restore)
        onRestore?()
        if let restoreError {
            throw restoreError
        }
        return restoreOutcomeToReturn
    }
}

@MainActor
private struct Harness {
    let viewModel: PaywallViewModel
    let purchaser: SpyPurchasing
    let appState: AppState

    init(plans: [PlanOption] = Harness.bothPlans) {
        purchaser = SpyPurchasing()
        purchaser.plansToReturn = plans
        viewModel = PaywallViewModel(purchasing: purchaser)
        appState = AppState()
    }

    static let monthly = PlanOption(
        id: "trays.plus.monthly",
        displayPrice: "$3.99",
        period: .month,
        freeTrial: .week
    )

    static let yearly = PlanOption(
        id: "trays.plus.yearly",
        displayPrice: "$29.99",
        period: .year,
        freeTrial: .week
    )

    /// Mirrors `SubscriptionService.products`, which is sorted by id.
    static let bothPlans = [monthly, yearly]

    /// Flips server truth the way `refreshEntitlement()` would.
    func grantEntitlement() {
        appState.currentUser = Harness.user(isSubscriber: true)
    }

    static func user(isSubscriber: Bool?) -> User {
        User(
            id: 1,
            username: "tester",
            email: "tester@example.com",
            bio: nil,
            profilePhotoUrl: nil,
            insertedAt: nil,
            confirmedAt: Date(),
            postCount: nil,
            followerCount: nil,
            followingCount: nil,
            followedByCurrentUser: nil,
            isAdmin: nil,
            isSubscriber: isSubscriber
        )
    }
}

// MARK: - Tests

/// Covers the paywall's load and write-path state machine: catalog absence vs.
/// failure, the "never unlock optimistically" invariant, the three distinct
/// purchase outcomes, and restore including the App Store cancel path.
///
/// **Still manual / Sandbox-only** — none of the following can be asserted
/// here, because `Product` and `Transaction` are not constructible outside the
/// StoreKit runtime AND `xcodebuild test` carries no StoreKit configuration at
/// all (`project.yml` binds `TraysSocial.storekit` to the Run action only, so
/// `Product.products(for:)` returns `[]` under test regardless):
///   - real catalog loading and `displayPrice` rendering in the storefront currency
///   - the `Product` -> `PlanOption` mapping in `LivePaywallPurchasing`
///     (period unit, intro-offer detection, `isEligibleForIntroOffer`)
///   - `product.purchase()` sheet presentation and `transaction.finish()`
///   - Ask-to-Buy resolving to an entitlement via `Transaction.updates`
///   - the manage-subscriptions sheet, and graceful re-lock on lapse
@MainActor
final class PaywallViewModelTests: XCTestCase {
    // MARK: - Load

    func test_load_populatesPlansInServiceOrder() async {
        let harness = Harness()

        await harness.viewModel.load()

        XCTAssertEqual(harness.viewModel.plans.map(\.id), ["trays.plus.monthly", "trays.plus.yearly"])
        XCTAssertEqual(harness.viewModel.loadState, .loaded(Harness.bothPlans))
    }

    /// An empty catalog is absence, not failure: `loadProducts()` never throws,
    /// so there is no error to surface — and nothing may toast on this path.
    func test_load_whenNoProducts_isUnavailableNotFailed() async {
        let harness = Harness(plans: [])

        await harness.viewModel.load()

        XCTAssertEqual(harness.viewModel.loadState, .unavailable)
        XCTAssertEqual(harness.viewModel.actionState, .idle)
        XCTAssertNil(harness.viewModel.statusMessage)
    }

    func test_load_defaultsSelectionToYearly() async {
        let harness = Harness()

        await harness.viewModel.load()

        XCTAssertEqual(harness.viewModel.selectedPlanID, "trays.plus.yearly")
    }

    func test_load_whenOnlyMonthlyAvailable_selectsMonthly() async {
        let harness = Harness(plans: [Harness.monthly])

        await harness.viewModel.load()

        XCTAssertEqual(harness.viewModel.selectedPlanID, "trays.plus.monthly")
    }

    func test_retryAfterUnavailable_reloadsAndSucceeds() async {
        let harness = Harness(plans: [])
        harness.purchaser.plansByCall = [[], Harness.bothPlans]

        await harness.viewModel.load()
        XCTAssertEqual(harness.viewModel.loadState, .unavailable)

        await harness.viewModel.retry()

        XCTAssertEqual(harness.viewModel.loadState, .loaded(Harness.bothPlans))
        XCTAssertEqual(harness.purchaser.calls, [.load, .load])
    }

    // MARK: - Purchase

    func test_purchase_passesSelectedPlanIDToStore() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.viewModel.selectedPlanID = "trays.plus.monthly"
        harness.purchaser.onPurchase = { harness.grantEntitlement() }

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.purchaser.calls, [.load, .purchase("trays.plus.monthly")])
    }

    func test_purchase_completedAndEntitled_reachesUnlocked() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.onPurchase = { harness.grantEntitlement() }

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertTrue(harness.appState.isPlus)
        XCTAssertEqual(harness.viewModel.actionState, .unlocked)
        XCTAssertTrue(harness.viewModel.isUnlocked)
    }

    /// The core invariant. `purchase()` returns `.completed` even when the
    /// server did not accept (SyncOutcome.alreadyInFlight), and
    /// `refreshCurrentUser()` swallows transient errors — so a completed
    /// purchase must NOT unlock the UI on its own.
    func test_purchase_completedButEntitlementNotLanded_doesNotUnlock() async {
        let harness = Harness()
        await harness.viewModel.load()
        // No grantEntitlement hook: server truth stays false.

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertFalse(harness.appState.isPlus)
        XCTAssertEqual(harness.viewModel.actionState, .awaitingEntitlement)
        XCTAssertFalse(harness.viewModel.isUnlocked)
    }

    func test_purchase_cancelled_isSilent() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.outcomeToReturn = .cancelled

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .idle)
        XCTAssertNil(harness.viewModel.statusMessage)
    }

    func test_purchase_pending_isNotCollapsedIntoCompletedOrCancelled() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.outcomeToReturn = .pending

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .pendingApproval)
        XCTAssertNotNil(harness.viewModel.statusMessage)
        XCTAssertFalse(harness.viewModel.isUnlocked)
    }

    func test_purchase_whenStoreThrows_showsMappedCopy() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.purchaseError = APIError.conflict(
            code: "transaction_already_claimed",
            message: "already linked"
        )

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(
            harness.viewModel.statusMessage,
            SubscriptionError.alreadyLinkedToAnotherAccount.errorDescription
        )
        XCTAssertFalse(harness.viewModel.isUnlocked)
    }

    func test_purchase_withNoSelection_isIgnored() async {
        let harness = Harness(plans: [])
        await harness.viewModel.load()

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.purchaser.calls, [.load])
        XCTAssertEqual(harness.viewModel.actionState, .idle)
    }

    // MARK: - Restore

    func test_restore_whenEntitlementFound_reachesUnlocked() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreOutcomeToReturn = .foundEntitlements
        harness.purchaser.onRestore = { harness.grantEntitlement() }

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .unlocked)
    }

    /// The false-negative guard. `SubscriptionService.restore()` calls
    /// `refreshEntitlement()` unconditionally and `AppState.refreshCurrentUser()`
    /// swallows transient errors, so a real subscriber on a flaky connection
    /// finishes restore with `isPlus == false`. Telling them "no active
    /// subscription found" would be a definitive statement about something we
    /// failed to check.
    func test_restore_whenEntitlementFoundButServerDidNotConfirm_doesNotClaimNothingToRestore() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreOutcomeToReturn = .foundEntitlements

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .restoreUnconfirmed)
        XCTAssertNotEqual(harness.viewModel.actionState, .nothingToRestore)
        XCTAssertNotEqual(
            harness.viewModel.statusMessage,
            String(localized: "No active subscription found for this Apple ID.")
        )
        XCTAssertFalse(harness.appState.isPlus, "an unconfirmed restore must never unlock")
    }

    func test_restore_whenNothingFound_reportsNothingToRestore() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreOutcomeToReturn = .noEntitlements

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .nothingToRestore)
        XCTAssertNotNil(harness.viewModel.statusMessage)
    }

    /// `AppStore.sync()` throws `StoreKitError.userCancelled` when the user
    /// dismisses the App Store credential prompt, and
    /// `SubscriptionError.from(_:)` has no StoreKit branch — so without the
    /// view model's interception this would surface the `.network` copy and
    /// tell someone who deliberately cancelled to check their connection.
    func test_restore_whenUserCancelsAppStorePrompt_isSilent() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreError = StoreKitError.userCancelled

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .idle)
        XCTAssertNil(harness.viewModel.statusMessage)
        XCTAssertNotEqual(harness.viewModel.statusMessage, SubscriptionError.network.errorDescription)
    }

    func test_restore_whenStoreThrows_showsMappedCopy() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreError = APIError.serverError(500)

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.statusMessage, SubscriptionError.network.errorDescription)
    }

    // MARK: - Derived state

    /// A charge has already been authorized; re-enabling Subscribe under
    /// "Purchase complete. Finishing activation." invites a second one. Restore
    /// stays enabled as the recovery path.
    func test_canPurchase_isFalseWhileAwaitingServerTruth() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.outcomeToReturn = .completed

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .awaitingEntitlement)
        XCTAssertFalse(harness.viewModel.canPurchase)
    }

    func test_canPurchase_isFalseWhilePendingApproval() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.outcomeToReturn = .pending

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .pendingApproval)
        XCTAssertFalse(harness.viewModel.canPurchase)
    }

    func test_canPurchase_returnsAfterDismissingAnUnconfirmedRestore() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreOutcomeToReturn = .foundEntitlements
        await harness.viewModel.restore(appState: harness.appState)
        XCTAssertFalse(harness.viewModel.canPurchase)

        harness.viewModel.dismissMessage()

        XCTAssertEqual(harness.viewModel.actionState, .idle)
        XCTAssertTrue(harness.viewModel.canPurchase)
    }

    func test_canPurchase_isFalseWhileNoPlanSelected() async {
        let harness = Harness(plans: [])

        await harness.viewModel.load()

        XCTAssertFalse(harness.viewModel.canPurchase)
    }

    func test_primaryButtonTitle_reflectsTrialAvailability() async {
        let harness = Harness(plans: [
            PlanOption(id: "trays.plus.yearly", displayPrice: "$29.99", period: .year, freeTrial: nil),
        ])

        await harness.viewModel.load()

        XCTAssertEqual(harness.viewModel.primaryButtonTitle, String(localized: "Subscribe"))
    }

    /// The banner renders its X off `isStatusDismissible`, so the two must agree
    /// or the user gets a control that does nothing — in the very states where
    /// Subscribe is also disabled.
    func test_isStatusDismissible_isFalseWhileWaitingOnServerTruth() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.outcomeToReturn = .completed

        await harness.viewModel.purchaseSelected(appState: harness.appState)

        XCTAssertEqual(harness.viewModel.actionState, .awaitingEntitlement)
        XCTAssertFalse(harness.viewModel.isStatusDismissible)
        XCTAssertNotNil(harness.viewModel.statusMessage)

        harness.viewModel.dismissMessage()

        XCTAssertEqual(harness.viewModel.actionState, .awaitingEntitlement, "a no-op X must not clear the wait")
    }

    func test_isStatusDismissible_isTrueForMessagesTheUserCanClear() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreOutcomeToReturn = .noEntitlements

        await harness.viewModel.restore(appState: harness.appState)

        XCTAssertTrue(harness.viewModel.isStatusDismissible)
    }

    func test_dismissMessage_clearsFailureBackToIdle() async {
        let harness = Harness()
        await harness.viewModel.load()
        harness.purchaser.restoreError = APIError.serverError(500)
        await harness.viewModel.restore(appState: harness.appState)
        XCTAssertNotNil(harness.viewModel.statusMessage)

        harness.viewModel.dismissMessage()

        XCTAssertEqual(harness.viewModel.actionState, .idle)
        XCTAssertNil(harness.viewModel.statusMessage)
    }
}
