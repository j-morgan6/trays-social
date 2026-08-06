@testable import TraysSocial
import XCTest

// MARK: - Fakes

//
// Declared at file scope rather than nested in the test case: swiftlint's
// `nesting` rule allows only one level, and `large_tuple` rules out returning
// the four collaborators as a tuple — hence the `Harness` struct below.

/// Shared ordered call log so cross-seam ordering (sync -> verify -> refresh)
/// is assertable as one sequence.
private final class CallLog {
    enum Call: Equatable {
        case verify(String)
        case refresh
        case sync
    }

    var calls: [Call] = []
}

private final class SpyBackend: SubscriptionBackend {
    let log: CallLog
    var errorToThrow: Error?
    /// Per-JWS overrides, so a restore can be driven with one transaction that
    /// fails and one that succeeds.
    var errorsByJWS: [String: Error] = [:]
    var verification = SubscriptionVerification(
        isSubscriber: true,
        productId: "trays.plus.monthly",
        environment: "Sandbox",
        originalTransactionId: "2000000012345678"
    )

    init(log: CallLog) {
        self.log = log
    }

    func verify(jws: String) async throws -> SubscriptionVerification {
        log.calls.append(.verify(jws))
        if let specific = errorsByJWS[jws] {
            throw specific
        }
        if let errorToThrow {
            throw errorToThrow
        }
        return verification
    }

    func refreshEntitlement() async {
        log.calls.append(.refresh)
    }
}

private final class SpyStoreKit: StoreKitSyncing {
    let log: CallLog
    var syncError: Error?
    var jwsToReturn: [String] = []

    init(log: CallLog) {
        self.log = log
    }

    func syncWithAppStore() async throws {
        log.calls.append(.sync)
        if let syncError {
            throw syncError
        }
    }

    func currentEntitlementJWS() async -> [String] {
        jwsToReturn
    }
}

@MainActor
private struct Harness {
    let service: SubscriptionService
    let backend: SpyBackend
    let storeKit: SpyStoreKit
    let log: CallLog

    init() {
        let log = CallLog()
        let backend = SpyBackend(log: log)
        let storeKit = SpyStoreKit(log: log)
        self.log = log
        self.backend = backend
        self.storeKit = storeKit
        service = SubscriptionService(backend: backend, storeKit: storeKit)
    }
}

/// W175: coverage for the Trays Plus purchase/entitlement plumbing.
///
/// Like `OptimisticRollbackTests`, this does NOT mock `APIClient` — that
/// singleton is hardcoded and mocking it globally would be the large refactor
/// that test file deliberately declined. Instead `SubscriptionService` takes two
/// feature-local seams (`SubscriptionBackend`, `StoreKitSyncing`), both expressed
/// in plain Foundation types. Nothing outside this feature is affected, and the
/// fakes need no StoreKit types — `Product` and `Transaction` are not
/// constructible outside the StoreKit runtime, which is precisely why the seams
/// are shaped this way. Tests build their own service, never `.shared`, so no
/// listener is started in the test process and no state leaks between cases.
///
/// **Automated here:** the money-critical wire shape (raw JWS passthrough), the
/// verify-then-refresh ordering, the "no entitlement without a server 200"
/// invariant, error mapping including the anti-oracle collapse, per-session
/// dedupe, the rejected-transaction guard that keeps `finish()` from running on
/// a server-refused purchase, and the `isPlus` truth table.
///
/// **Still manual** (see the task's verification steps): `Product.products(for:)`
/// loading, `product.purchase()` result unwrapping, `transaction.finish()`, and
/// real `Transaction.updates` delivery on renewal/refund. Those need a Sandbox
/// tester against App Store Connect products.
@MainActor
final class SubscriptionServiceTests: XCTestCase {
    // MARK: - JWS passthrough (the build-15 double-encode regression)

    func test_syncEntitlement_forwardsJWSByteIdentical() async throws {
        let harness = Harness()
        // Realistic shape: three base64url segments joined by dots. Any
        // re-encoding on the way out would alter this string.
        let jws = "eyJhbGciOiJFUzI1NiJ9.eyJwcm9kdWN0SWQiOiJ0cmF5cy5wbHVzLm1vbnRobHkifQ.c2ln"

        _ = try await harness.service.syncEntitlement(jws: jws)

        XCTAssertEqual(harness.log.calls.first, .verify(jws))
    }

    func test_syncEntitlement_verifiesThenRefreshes_inThatOrder() async throws {
        let harness = Harness()

        _ = try await harness.service.syncEntitlement(jws: "a.b.c")

        XCTAssertEqual(harness.log.calls, [.verify("a.b.c"), .refresh])
    }

    // MARK: - No entitlement without a server 200

    func test_syncEntitlement_whenVerifyFails_doesNotRefresh() async {
        let harness = Harness()
        harness.backend.errorToThrow = APIError.unprocessableEntity

        do {
            _ = try await harness.service.syncEntitlement(jws: "a.b.c")
            XCTFail("Expected syncEntitlement to throw")
        } catch {
            XCTAssertEqual(error as? SubscriptionError, .couldNotVerify)
        }

        // The refresh is unreachable on the failure path — this is the invariant
        // that stops a failed purchase from ever unlocking the UI.
        XCTAssertEqual(harness.log.calls, [.verify("a.b.c")])
    }

    func test_syncEntitlement_409_mapsToAlreadyLinked() async {
        let harness = Harness()
        harness.backend.errorToThrow = APIError.conflict(
            code: "transaction_already_claimed",
            message: "this subscription is already linked to another account"
        )

        do {
            _ = try await harness.service.syncEntitlement(jws: "a.b.c")
            XCTFail("Expected syncEntitlement to throw")
        } catch {
            XCTAssertEqual(error as? SubscriptionError, .alreadyLinkedToAnotherAccount)
        }
    }

    // MARK: - A rejected transaction must never be mistaken for an accepted one

    /// Regression: the dedupe set once recorded rejections and successes alike,
    /// so a redelivered *rejected* transaction returned without throwing — and
    /// both finish() call sites treat "did not throw" as "the server accepted
    /// it". That would finish a transaction the server explicitly refused.
    func test_rejectedTransaction_keepsThrowingOnRedelivery() async {
        let harness = Harness()
        harness.backend.errorToThrow = APIError.conflict(
            code: "transaction_already_claimed",
            message: "already linked"
        )

        for attempt in 1 ... 2 {
            do {
                _ = try await harness.service.syncEntitlement(jws: "x.y.z")
                XCTFail("Attempt \(attempt): expected syncEntitlement to throw")
            } catch {
                XCTAssertEqual(error as? SubscriptionError, .alreadyLinkedToAnotherAccount)
            }
        }

        // Thrown both times, but only hit the network once.
        XCTAssertEqual(harness.log.calls, [.verify("x.y.z")])
    }

    func test_alreadyVerifiedOutcome_isSafeToFinish() async throws {
        let harness = Harness()

        _ = try await harness.service.syncEntitlement(jws: "a.b.c")
        let outcome = try await harness.service.syncEntitlement(jws: "a.b.c")

        XCTAssertEqual(outcome, .alreadyVerified)
        XCTAssertTrue(outcome.isServerAccepted, "A previously accepted transaction is safe to finish")
    }

    func test_undecodable409_isTerminalNotTransient() {
        // An undecodable 409 body still means permanent conflict. Mapping it to
        // .network would present it as a connection blip and invite a retry loop.
        XCTAssertEqual(SubscriptionError.from(APIError.serverError(409)), .couldNotVerify)
        XCTAssertEqual(SubscriptionError.from(APIError.serverError(500)), .network)
    }

    // MARK: - Anti-oracle: every 422 reason produces identical user-facing copy

    func test_allVerifyRejectionCodes_produceIdenticalMessage() {
        let codes = ["invalid_transaction", "unknown_product", "environment_mismatch"]

        let messages = codes.map { code -> String in
            let apiError = APIError.validationError([
                FieldError(field: nil, message: "rejected", code: code),
            ])
            return SubscriptionError.from(apiError).errorDescription ?? ""
        }

        XCTAssertEqual(Set(messages).count, 1, "Rejection reasons must not be distinguishable by copy")
        XCTAssertEqual(messages.first, SubscriptionError.couldNotVerify.errorDescription)
    }

    // MARK: - Restore

    func test_restore_syncsThenVerifiesEachThenRefreshes() async throws {
        let harness = Harness()
        harness.storeKit.jwsToReturn = ["one.jws.sig", "two.jws.sig"]

        try await harness.service.restore()

        XCTAssertEqual(harness.log.calls, [
            .sync,
            .verify("one.jws.sig"), .refresh,
            .verify("two.jws.sig"), .refresh,
            .refresh,
        ])
    }

    func test_restore_whenAppStoreSyncFails_doesNotVerify() async {
        let harness = Harness()
        harness.storeKit.syncError = APIError.serverError(500)
        harness.storeKit.jwsToReturn = ["one.jws.sig"]

        do {
            try await harness.service.restore()
            XCTFail("Expected restore to throw")
        } catch {
            XCTAssertEqual(error as? SubscriptionError, .network)
        }

        XCTAssertEqual(harness.log.calls, [.sync])
    }

    func test_restore_withNoEntitlements_stillRefreshesServerTruth() async throws {
        let harness = Harness()
        harness.storeKit.jwsToReturn = []

        try await harness.service.restore()

        // The re-lock case: nothing to verify, but server truth must still be
        // re-read so a lapsed subscription drops isPlus.
        XCTAssertEqual(harness.log.calls, [.sync, .refresh])
    }

    func test_restore_partialFailure_verifiesOthersAndStillRefreshes() async {
        let harness = Harness()
        harness.storeKit.jwsToReturn = ["foreign.jws.sig", "mine.jws.sig"]
        harness.backend.errorsByJWS = [
            "foreign.jws.sig": APIError.conflict(
                code: "transaction_already_claimed",
                message: "already linked"
            ),
        ]

        do {
            try await harness.service.restore()
            XCTFail("Expected restore to rethrow the first failure")
        } catch {
            XCTAssertEqual(error as? SubscriptionError, .alreadyLinkedToAnotherAccount)
        }

        // The foreign transaction must not abort the user's own, and server truth
        // must still be re-read before the error surfaces.
        XCTAssertEqual(harness.log.calls, [
            .sync,
            .verify("foreign.jws.sig"),
            .verify("mine.jws.sig"), .refresh,
            .refresh,
        ])
    }

    // MARK: - Per-session dedupe and the cross-account guard

    func test_syncEntitlement_deduplicatesWithinSession() async throws {
        let harness = Harness()

        _ = try await harness.service.syncEntitlement(jws: "same.jws.sig")
        _ = try await harness.service.syncEntitlement(jws: "same.jws.sig")

        // Verified once. The second refresh is deliberate: refreshCurrentUser()
        // swallows transient errors, so a dedupe hit re-reads server truth rather
        // than leaving a paying user locked out for the session.
        XCTAssertEqual(harness.log.calls, [.verify("same.jws.sig"), .refresh, .refresh])
    }

    func test_handleSignOut_clearsDedupe_soNextAccountReverifies() async throws {
        let harness = Harness()
        _ = try await harness.service.syncEntitlement(jws: "same.jws.sig")

        harness.service.handleSignOut()
        _ = try await harness.service.syncEntitlement(jws: "same.jws.sig")

        // Without this, account B would skip re-verifying and would never get
        // bound to the transaction.
        XCTAssertEqual(harness.log.calls, [
            .verify("same.jws.sig"), .refresh,
            .verify("same.jws.sig"), .refresh,
        ])
    }

    func test_handleSignOut_clearsRejections_soNextAccountCanClaim() async throws {
        let harness = Harness()
        harness.backend.errorsByJWS = [
            "x.y.z": APIError.conflict(code: "transaction_already_claimed", message: "linked"),
        ]
        _ = try? await harness.service.syncEntitlement(jws: "x.y.z")

        // The rejection was account-scoped: the account it IS bound to must be
        // able to claim it after signing in.
        harness.service.handleSignOut()
        harness.backend.errorsByJWS = [:]
        let outcome = try await harness.service.syncEntitlement(jws: "x.y.z")

        XCTAssertEqual(outcome, .verified(harness.backend.verification))
    }

    // MARK: - AppState.isPlus reads server truth only

    func test_isPlus_truthTable() {
        let appState = AppState()

        appState.currentUser = nil
        XCTAssertFalse(appState.isPlus, "No user means no entitlement")

        appState.currentUser = user(isSubscriber: nil)
        XCTAssertFalse(appState.isPlus, "Absent key is treated as false")

        appState.currentUser = user(isSubscriber: false)
        XCTAssertFalse(appState.isPlus)

        appState.currentUser = user(isSubscriber: true)
        XCTAssertTrue(appState.isPlus)
    }

    func test_isPlus_isFalseAfterCurrentUserCleared() {
        let appState = AppState()
        appState.currentUser = user(isSubscriber: true)
        XCTAssertTrue(appState.isPlus)

        appState.currentUser = nil

        XCTAssertFalse(appState.isPlus, "Entitlement must not survive the user being cleared")
    }

    // MARK: - Helpers

    private func user(isSubscriber: Bool?) -> User {
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
