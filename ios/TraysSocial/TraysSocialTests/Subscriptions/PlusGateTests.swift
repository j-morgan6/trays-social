@testable import TraysSocial
import XCTest

/// Covers the two decisions the Plus presentation layer makes outside the view
/// model: what a gate tap does, and which face the Settings section shows.
///
/// Both were lifted out of their `body` blocks precisely so they could be tested
/// — the project has no view-test infrastructure (no ViewInspector, no XCUITest
/// target), so anything left inline in a SwiftUI `body` is asserted by nothing.
/// The gate's branch is the single most product-critical line in W176: getting
/// it backwards would gate a paying user out, or hand a free user the feature.
@MainActor
final class PlusGateTests: XCTestCase {
    // MARK: - Gate decision

    func test_gate_whenEntitled_runsActionImmediately() {
        XCTAssertEqual(PlusGateOutcome.decide(isPlus: true), .run)
    }

    func test_gate_whenNotEntitled_presentsPaywall() {
        XCTAssertEqual(PlusGateOutcome.decide(isPlus: false), .presentPaywall)
    }

    /// Entitlement is server truth read off `AppState.isPlus` (`/auth/me`).
    /// Driving the decision through a live `AppState` — rather than a bare Bool —
    /// is what proves the gate reads that property and nothing local.
    func test_gate_followsAppStateEntitlement() {
        let appState = AppState()
        XCTAssertEqual(PlusGateOutcome.decide(isPlus: appState.isPlus), .presentPaywall)

        appState.currentUser = Self.user(isSubscriber: true)

        XCTAssertTrue(appState.isPlus)
        XCTAssertEqual(PlusGateOutcome.decide(isPlus: appState.isPlus), .run)
    }

    /// Every gated feature routes through the same decision. A per-feature
    /// override is exactly how "nothing free is blocked" would erode.
    func test_gate_decisionIsIdenticalForEveryPlusFeature() {
        for feature in PlusFeature.allCases {
            XCTAssertEqual(PlusGateOutcome.decide(isPlus: false), .presentPaywall, "\(feature)")
            XCTAssertEqual(PlusGateOutcome.decide(isPlus: true), .run, "\(feature)")
        }
    }

    // MARK: - Settings section

    func test_settingsSection_whenSubscribed_showsStatusAndManage() {
        XCTAssertEqual(PlusSettingsState.from(isPlus: true), .subscribed)
    }

    func test_settingsSection_whenFree_showsPaywallEntry() {
        XCTAssertEqual(PlusSettingsState.from(isPlus: false), .notSubscribed)
    }

    func test_settingsSection_switchesWhenEntitlementLands() {
        let appState = AppState()
        XCTAssertEqual(PlusSettingsState.from(isPlus: appState.isPlus), .notSubscribed)

        appState.currentUser = Self.user(isSubscriber: true)

        XCTAssertEqual(PlusSettingsState.from(isPlus: appState.isPlus), .subscribed)
    }

    // MARK: - Fixtures

    /// Mirrors `Harness.user` in PaywallViewModelTests.swift, which is
    /// file-private there. Duplicated rather than hoisted: sharing it would mean
    /// a fixtures file whose only client is two tests in the same folder.
    private static func user(isSubscriber: Bool) -> User {
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
