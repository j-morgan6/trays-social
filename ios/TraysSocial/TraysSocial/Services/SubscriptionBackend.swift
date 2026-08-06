import Foundation
import os
import StoreKit

// NOTE: this file and SubscriptionService.swift import StoreKit but deliberately
// NOT SwiftUI. SwiftUI also declares a `Transaction` type, and importing both
// makes the bare name ambiguous. If SwiftUI ever becomes necessary here, qualify
// every use as `StoreKit.Transaction`.

private let subLog = Logger(subsystem: "com.trays.social", category: "subscription")

/// W175: the two seams the subscription stack talks to. Both are expressed in
/// plain Foundation types — no StoreKit types cross either boundary — so tests
/// can fake them without constructing a `Product` or a `Transaction`, neither of
/// which is instantiable outside the StoreKit runtime.
///
/// This is a *feature-local* seam, in the same spirit as `AdProviding` in
/// AdProvider.swift (W158). It deliberately does NOT mock `APIClient`: the
/// project made a considered decision not to do that (see the preamble in
/// OptimisticRollbackTests.swift), because the singleton is hardcoded and
/// mocking it globally would be a large refactor. Nothing outside
/// `SubscriptionService` is affected by these protocols existing.
@MainActor
protocol SubscriptionBackend {
    /// POSTs a StoreKit signed transaction to the server for verification.
    @discardableResult
    func verify(jws: String) async throws -> SubscriptionVerification
    /// Re-reads server truth (`/auth/me`) so `AppState.isPlus` reflects it.
    func refreshEntitlement() async
}

/// The StoreKit half of the seam. Only `LiveStoreKitSyncing` touches StoreKit's
/// entitlement APIs — a grep for `currentEntitlements` should hit this file and
/// nowhere else.
@MainActor
protocol StoreKitSyncing {
    /// `AppStore.sync()`. Prompts for App Store credentials, so this is only
    /// ever called from a user-initiated restore — never a background drain.
    func syncWithAppStore() async throws
    /// Signed representations of every currently-entitled transaction.
    func currentEntitlementJWS() async -> [String]
}

// MARK: - Live implementations

@MainActor
final class LiveSubscriptionBackend: SubscriptionBackend {
    /// Weak so the service (a singleton) never keeps AppState alive. Assigned by
    /// `SubscriptionService.configure(appState:)` at app launch.
    weak var appState: AppState?

    init(appState: AppState? = nil) {
        self.appState = appState
    }

    /// The wire shape is exactly `{"jws": "<raw string>"}`.
    ///
    /// `jws` is StoreKit's `transaction.jwsRepresentation` and MUST be passed
    /// through untouched. `JSONEncoder.apiEncoder` performs the one and only
    /// encoding pass. Do NOT base64-encode, re-serialize, or otherwise "helpfully"
    /// pre-process it — that is the class of bug that shipped in build 15, where a
    /// double-encoded bearer locked every Apple Sign In user out. The server
    /// collapses a double-encoded payload into a generic 422, so the symptom would
    /// be "every purchase silently fails to verify".
    struct VerifyRequest: Encodable {
        let jws: String
    }

    @discardableResult
    func verify(jws: String) async throws -> SubscriptionVerification {
        let body = VerifyRequest(jws: jws)
        let response: DataResponse<SubscriptionVerification> = try await APIClient.shared.post(
            path: "/subscriptions/verify",
            body: body
        )
        return response.data
    }

    func refreshEntitlement() async {
        // Reuse the existing app-wide /auth/me path rather than adding a second
        // caller — AppState.refreshCurrentUser() already guards on isAuthenticated
        // and swallows transient errors.
        await appState?.refreshCurrentUser()
    }
}

@MainActor
final class LiveStoreKitSyncing: StoreKitSyncing {
    func syncWithAppStore() async throws {
        try await AppStore.sync()
    }

    func currentEntitlementJWS() async -> [String] {
        var result: [String] = []
        for await entitlement in StoreKit.Transaction.currentEntitlements {
            switch entitlement {
            case .verified:
                // NOTE: jwsRepresentation is on VerificationResult, NOT on the
                // unwrapped Transaction — read it off the envelope.
                result.append(entitlement.jwsRepresentation)
            case let .unverified(_, error):
                // StoreKit itself could not verify the signature. Never forward
                // it — the server would reject it anyway, and forwarding would
                // just burn rate limit.
                subLog.error("Dropping unverified entitlement: \(error.localizedDescription, privacy: .public)")
            }
        }
        return result
    }
}

// MARK: - Errors

/// User-facing failures for the subscription flow.
///
/// Copy is authored with `String(localized:)` so the keys are extractable, but
/// the fr/es catalog entries are deliberately deferred to W176 (the paywall),
/// which is the first surface that actually displays any of these. W175 ships no
/// UI, so adding catalog entries now would churn Localizable.xcstrings for
/// strings with no display surface.
enum SubscriptionError: LocalizedError, Equatable {
    /// Every 422 from the verify endpoint collapses to this single case on
    /// purpose. The server deliberately does not distinguish bad signature from
    /// tampered payload from wrong bundle id (anti-oracle design), so neither
    /// does the client. The specific code is logged, never shown.
    case couldNotVerify
    /// 409 — this subscription's original_transaction_id is already bound to a
    /// different Trays account. Distinct copy, because it is the one failure the
    /// user can actually act on (sign in with the other account).
    case alreadyLinkedToAnotherAccount
    /// 403 from RequireConfirmedPlug.
    case emailNotConfirmed
    case notSignedIn
    /// Transport failure, rate limit, or 5xx — all retryable.
    case network

    var errorDescription: String? {
        switch self {
        case .couldNotVerify:
            String(localized: "We couldn't verify that purchase. You have not been charged again.")
        case .alreadyLinkedToAnotherAccount:
            String(localized: "This subscription is already linked to another Trays account.")
        case .emailNotConfirmed:
            String(localized: "Confirm your email to activate Trays Plus.")
        case .notSignedIn:
            String(localized: "Sign in to activate Trays Plus.")
        case .network:
            String(localized: "Couldn't reach Trays. Check your connection and try again.")
        }
    }

    /// Maps a transport/API error onto the user-facing set.
    static func from(_ error: Error) -> SubscriptionError {
        if let subscriptionError = error as? SubscriptionError {
            return subscriptionError
        }
        guard let apiError = error as? APIError else { return .network }

        switch apiError {
        case .validationError, .unprocessableEntity:
            // invalid_transaction / unknown_product / environment_mismatch all
            // land here and MUST produce identical user-facing copy.
            return .couldNotVerify
        case let .conflict(code, _):
            return code == "transaction_already_claimed" ? .alreadyLinkedToAnotherAccount : .couldNotVerify
        case .serverError(409):
            // An undecodable 409 body still means "permanent conflict". Without
            // this it would fall through to .network and be presented as a
            // transient connection problem, inviting an endless retry loop.
            return .couldNotVerify
        case .forbidden:
            return .emailNotConfirmed
        case .unauthorized, .suspended:
            // A suspension logs the user out through the existing global path,
            // which surfaces the real reason on LoginView.
            return .notSignedIn
        default:
            return .network
        }
    }
}
