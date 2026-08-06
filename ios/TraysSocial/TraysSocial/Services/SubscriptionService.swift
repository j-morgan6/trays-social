import Foundation
import os
import StoreKit

// See the note in SubscriptionBackend.swift: StoreKit yes, SwiftUI no — both
// declare a `Transaction` type.

private let storeLog = Logger(subsystem: "com.trays.social", category: "subscription")

/// W175: the single mutation point for the Trays Plus purchase stack.
///
/// Everything outside this type talks to `AppState.isPlus` (server truth) or to
/// this service's public API — never to StoreKit directly. So when the product
/// catalog changes, or StoreKit's API shifts again, the blast radius is this file
/// plus `LiveStoreKitSyncing`; the paywall (W176), collections (W177), and
/// planner (W178) surfaces stay untouched.
///
/// **The server is the sole entitlement authority.** Local StoreKit state only
/// ever *triggers a sync*; it never unlocks anything. Every path funnels through
/// `syncEntitlement(jws:)`, which verifies server-side and then re-reads
/// `/auth/me`. That indirection is the graceful re-lock mechanism: when a
/// subscription lapses the server flips `is_subscriber`, the next refresh
/// re-locks the UI, and no user data is touched.
@MainActor
@Observable
final class SubscriptionService {
    static let shared = SubscriptionService()

    /// Must match the server's allowlist in `config/config.exs` (`:app_store`
    /// `product_ids`) exactly — an id the server doesn't know 422s as
    /// `unknown_product`. Product ids are permanent once created in App Store
    /// Connect, so a typo here is not recoverable by editing the product later.
    static let productIDs = ["trays.plus.monthly", "trays.plus.yearly"]

    private(set) var products: [Product] = []

    private let backend: any SubscriptionBackend
    private let storeKit: any StoreKitSyncing
    private var listenerTask: Task<Void, Never>?

    /// Signed transactions the SERVER ACCEPTED this session. StoreKit redelivers
    /// unfinished transactions aggressively; without this a single stuck
    /// transaction would hit the verify endpoint on every launch and every shell
    /// mount. Cleared on sign-out — see `handleSignOut()`.
    private var syncedTransactions: Set<String> = []

    /// Signed transactions the server PERMANENTLY REFUSED this session (409 —
    /// bound to a different account). Tracked separately from
    /// `syncedTransactions` on purpose: collapsing the two would make a repeat
    /// delivery of a *rejected* transaction return without throwing, and both
    /// `finish()` call sites treat "did not throw" as "the server accepted it" —
    /// which would finish a transaction the server explicitly refused.
    private var rejectedTransactions: Set<String> = []

    /// Signed transactions with a verify request currently in flight. The
    /// membership check in `syncEntitlement` straddles an `await`, and there are
    /// two genuine concurrent producers (the post-login drain and the always-on
    /// Transaction.updates listener), so without this the same JWS can be POSTed
    /// twice on a launch that follows a purchase.
    private var inFlightTransactions: Set<String> = []

    /// Internal (not private) so tests can inject fakes. Production code uses
    /// `.shared`; nothing else should construct this type.
    init(
        backend: any SubscriptionBackend = LiveSubscriptionBackend(),
        storeKit: any StoreKitSyncing = LiveStoreKitSyncing()
    ) {
        self.backend = backend
        self.storeKit = storeKit
    }

    /// Hands the live backend the AppState it needs for `/auth/me` refreshes.
    /// No-op when a fake backend is injected, which is what tests want.
    func configure(appState: AppState) {
        (backend as? LiveSubscriptionBackend)?.appState = appState
    }

    // MARK: - Core sync (StoreKit-free, and therefore unit-testable)

    /// The three ways a sync can succeed-or-be-skipped. Callers that hold a real
    /// `Transaction` MUST branch on this before calling `finish()` — only
    /// `.verified` and `.alreadyVerified` mean the server has accepted this
    /// transaction. A bare "did not throw" is NOT sufficient.
    enum SyncOutcome: Equatable {
        /// The server accepted it on this call.
        case verified(SubscriptionVerification)
        /// The server accepted it earlier this session — safe to finish.
        case alreadyVerified
        /// Another caller is verifying it right now — do NOT finish; whoever owns
        /// the in-flight request will, or StoreKit redelivers next launch.
        case alreadyInFlight

        /// Whether the server is known to have accepted this transaction.
        var isServerAccepted: Bool {
            switch self {
            case .verified, .alreadyVerified: true
            case .alreadyInFlight: false
            }
        }

        static func == (lhs: SyncOutcome, rhs: SyncOutcome) -> Bool {
            switch (lhs, rhs) {
            case (.verified, .verified), (.alreadyVerified, .alreadyVerified),
                 (.alreadyInFlight, .alreadyInFlight):
                true
            default:
                false
            }
        }
    }

    /// Verify one signed transaction server-side, then re-read server truth.
    ///
    /// Throws a mapped `SubscriptionError` on failure — and critically, on the
    /// failure path `refreshEntitlement()` is never reached, so no entitlement
    /// can be granted without a server 200.
    @discardableResult
    func syncEntitlement(jws: String) async throws -> SyncOutcome {
        // A permanent rejection must keep throwing on every redelivery, not
        // silently succeed. This is what stops finish() from being called on a
        // transaction the server refused.
        if rejectedTransactions.contains(jws) {
            throw SubscriptionError.alreadyLinkedToAnotherAccount
        }
        if syncedTransactions.contains(jws) {
            // Re-run the refresh rather than returning immediately.
            // AppState.refreshCurrentUser() swallows transient errors, so if the
            // refresh that followed the original verify failed, short-circuiting
            // here would leave a paying user locked out for the rest of the
            // session despite a successful server-side purchase.
            await backend.refreshEntitlement()
            return .alreadyVerified
        }
        if inFlightTransactions.contains(jws) {
            return .alreadyInFlight
        }

        inFlightTransactions.insert(jws)
        defer { inFlightTransactions.remove(jws) }

        do {
            let verification = try await backend.verify(jws: jws)
            syncedTransactions.insert(jws)
            await backend.refreshEntitlement()
            return .verified(verification)
        } catch {
            let mapped = SubscriptionError.from(error)
            // A transaction bound to another account will never succeed for this
            // one, so stop re-attempting it — but record it as REJECTED, never as
            // synced, so subsequent deliveries keep throwing.
            if mapped == .alreadyLinkedToAnotherAccount {
                rejectedTransactions.insert(jws)
            }
            throw mapped
        }
    }

    /// Called from every credential-clearing exit in AppState.
    ///
    /// `isPlus` reads `currentUser.isSubscriber`, which `logout()` already nils,
    /// so there is no local entitlement to inherit. The genuinely dangerous
    /// cross-account state is the dedupe set: if it survived sign-out, account B
    /// would skip re-verifying and would never get bound to the transaction.
    func handleSignOut() {
        listenerTask?.cancel()
        listenerTask = nil
        syncedTransactions.removeAll()
        rejectedTransactions.removeAll()
        inFlightTransactions.removeAll()
        products.removeAll()
        // Restart immediately — a listener must be alive for the app's lifetime.
        startTransactionListener()
    }

    // MARK: - StoreKit surface

    func loadProducts() async {
        do {
            let loaded = try await Product.products(for: Self.productIDs)
            products = loaded.sorted { $0.id < $1.id }
            if loaded.count != Self.productIDs.count {
                // Product.products(for:) does NOT throw on an unknown id or a
                // missing StoreKit configuration — it silently returns fewer
                // products. Without this, a misconfigured scheme or a product-id
                // typo is indistinguishable from an empty paywall. Product ids
                // are not sensitive, so log them.
                let missing = Set(Self.productIDs).subtracting(loaded.map(\.id))
                    .sorted().joined(separator: ", ")
                storeLog.error("Product catalog incomplete; missing: \(missing, privacy: .public)")
            }
        } catch {
            // Read path — log only, never toast (D95).
            storeLog.error("Product load failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    /// How a purchase attempt ended. Distinguishing these matters to the W176
    /// paywall: `.cancelled` should show nothing, while `.pending` (Ask to Buy /
    /// SCA) should show a waiting-for-approval state.
    enum PurchaseOutcome: Equatable {
        case completed
        case cancelled
        case pending
    }

    /// User-initiated purchase. Callers (the W176 paywall) MAY surface a toast on
    /// a thrown error — this is a write path.
    @discardableResult
    func purchase(_ product: Product) async throws -> PurchaseOutcome {
        let result = try await product.purchase()

        switch result {
        case let .success(verification):
            guard case let .verified(transaction) = verification else {
                // StoreKit couldn't verify its own signature. Do not finish it.
                throw SubscriptionError.couldNotVerify
            }
            // jwsRepresentation lives on the VerificationResult envelope, not on
            // the unwrapped Transaction.
            let outcome = try await syncEntitlement(jws: verification.jwsRepresentation)
            // Strictly after the server accepted. Finishing earlier — or merely
            // because syncEntitlement didn't throw — would let an unverified
            // purchase escape validation permanently.
            guard outcome.isServerAccepted else { return .completed }
            await transaction.finish()
            return .completed
        case .userCancelled:
            return .cancelled
        case .pending:
            // Ask to Buy / SCA. The listener picks it up when it resolves.
            return .pending
        @unknown default:
            // Unknown future state: show nothing. A genuinely completed purchase
            // still reaches us through the Transaction.updates listener.
            return .cancelled
        }
    }

    /// User-initiated restore. `AppStore.sync()` prompts for App Store
    /// credentials, which is why the background drain below does not call it.
    func restore() async throws {
        do {
            try await storeKit.syncWithAppStore()
        } catch {
            throw SubscriptionError.from(error)
        }

        // Per-entitlement failures must not abort the whole restore: a user can
        // hold one transaction bound to another account AND one legitimately
        // theirs, and the foreign one must not stop the legitimate one from
        // verifying.
        var firstFailure: Error?
        for jws in await storeKit.currentEntitlementJWS() {
            do {
                try await syncEntitlement(jws: jws)
            } catch {
                storeLog.error("Restore: entitlement sync failed: \(error.localizedDescription, privacy: .public)")
                if firstFailure == nil {
                    firstFailure = error
                }
            }
        }

        // Unconditional, and BEFORE any rethrow: a restore that surfaces zero
        // active entitlements — or that partially fails — still has to re-read
        // server truth. That is the re-lock case.
        await backend.refreshEntitlement()

        if let firstFailure {
            throw firstFailure
        }
    }

    /// Post-login drain. Binds a purchase made while signed out, on a reinstall,
    /// or on a second device to the now-authenticated account.
    ///
    /// Read path: every failure is logged, never toasted (D95).
    func syncCurrentEntitlements() async {
        guard KeychainService.getToken() != nil else { return }

        for jws in await storeKit.currentEntitlementJWS() {
            do {
                try await syncEntitlement(jws: jws)
            } catch {
                storeLog.error("Entitlement drain failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

    /// Idempotent. Started at launch and kept alive for the app's lifetime — a
    /// renewal that happens while the app is running is delivered exactly once,
    /// so a listener that only attaches after login would miss it.
    func startTransactionListener() {
        guard listenerTask == nil else { return }

        listenerTask = Task { [weak self] in
            for await update in StoreKit.Transaction.updates {
                await self?.handle(update)
            }
        }
    }

    private func handle(_ update: VerificationResult<StoreKit.Transaction>) async {
        guard case let .verified(transaction) = update else {
            storeLog.error("Dropping unverified transaction update")
            return
        }

        // Signed out: do NOT verify and do NOT finish. Leaving it unfinished is
        // exactly what makes it recoverable — StoreKit redelivers on next launch,
        // and it stays in currentEntitlements for the post-login drain.
        guard KeychainService.getToken() != nil else {
            storeLog.notice("Transaction arrived while signed out; left unfinished for redelivery")
            return
        }

        do {
            // jwsRepresentation is on the VerificationResult envelope.
            let outcome = try await syncEntitlement(jws: update.jwsRepresentation)
            // Only finish once the server is known to have accepted it.
            guard outcome.isServerAccepted else { return }
            await transaction.finish()
        } catch {
            // Background sync is a read path — log, never toast (D95).
            storeLog.error("Transaction sync failed: \(error.localizedDescription, privacy: .public)")
        }
    }
}
