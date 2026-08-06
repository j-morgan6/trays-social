import Foundation
import os
import StoreKit

// NOTE: this file deliberately does NOT `import SwiftUI`. Both SwiftUI and
// StoreKit declare `Transaction`, and the ambiguity is a compile error that
// only shows up once someone adds an unrelated view helper here. Same rule as
// Services/SubscriptionService.swift.

private let paywallLog = Logger(subsystem: "com.trays.social", category: "paywall")

/// Display model for one purchasable plan.
///
/// Deliberately StoreKit-free. `Product` cannot be constructed outside the
/// StoreKit runtime, so a view model that stored `[Product]` would be
/// untestable past its empty state — and the test action carries no StoreKit
/// configuration at all (`project.yml` binds `TraysSocial.storekit` to the Run
/// action only), so `Product.products(for:)` returns `[]` under `xcodebuild
/// test` no matter what. Keeping the view model's vocabulary in plain value
/// types is what makes the purchase state machine assertable. Same reasoning as
/// the `SubscriptionBackend` / `StoreKitSyncing` seams W175 introduced.
struct PlanOption: Identifiable, Equatable, Sendable {
    enum Period: Equatable, Sendable {
        case month
        case year
        case other
    }

    /// The introductory free trial, when one is configured AND this Apple ID is
    /// still eligible for it. `nil` covers both "no trial offered" and "already
    /// used" — the paywall must not promise a trial the user cannot get.
    enum FreeTrial: Equatable, Sendable {
        case week
        case month
        case other
    }

    /// The App Store product id, e.g. `trays.plus.monthly`.
    let id: String
    /// Locale-correct, straight from `Product.displayPrice`. Never a literal.
    let displayPrice: String
    let period: Period
    let freeTrial: FreeTrial?

    var isYearly: Bool {
        period == .year
    }
}

/// The seam the paywall talks to. `Product` never crosses this boundary.
@MainActor
protocol PaywallPurchasing {
    /// Never throws: the underlying `SubscriptionService.loadProducts()` logs
    /// and leaves the catalog empty rather than surfacing an error.
    func loadPlans() async -> [PlanOption]
    func purchase(planID: String) async throws -> SubscriptionService.PurchaseOutcome
    /// Returns what the App Store actually surfaced, so the caller can tell
    /// "you own nothing" apart from "we could not confirm it".
    func restore() async throws -> SubscriptionService.RestoreOutcome
}

/// Production implementation — the only new type that touches `Product`.
@MainActor
final class LivePaywallPurchasing: PaywallPurchasing {
    private let service: SubscriptionService

    init(service: SubscriptionService = .shared) {
        self.service = service
    }

    func loadPlans() async -> [PlanOption] {
        await service.loadProducts()
        var options: [PlanOption] = []
        for product in service.products {
            await options.append(Self.planOption(from: product))
        }
        return options
    }

    func purchase(planID: String) async throws -> SubscriptionService.PurchaseOutcome {
        guard let product = service.products.first(where: { $0.id == planID }) else {
            // The catalog changed under us between load and tap. Treat it the
            // same as a purchase we cannot vouch for rather than silently
            // no-op'ing, so the user gets an explanation.
            throw SubscriptionError.couldNotVerify
        }
        return try await service.purchase(product)
    }

    func restore() async throws -> SubscriptionService.RestoreOutcome {
        try await service.restore()
    }

    private static func planOption(from product: Product) async -> PlanOption {
        let subscription = product.subscription

        let period: PlanOption.Period = switch subscription?.subscriptionPeriod.unit {
        case .month: .month
        case .year: .year
        default: .other
        }

        var trial: PlanOption.FreeTrial?
        if let subscription,
           let offer = subscription.introductoryOffer,
           offer.paymentMode == .freeTrial,
           await subscription.isEligibleForIntroOffer
        {
            trial = switch offer.period.unit {
            case .week: .week
            case .month: .month
            default: .other
            }
        }

        return PlanOption(
            id: product.id,
            displayPrice: product.displayPrice,
            period: period,
            freeTrial: trial
        )
    }
}

/// Catalog load.
///
/// Modelled as *absence*, not failure, and that is deliberate:
/// `SubscriptionService.loadProducts()` never throws — on any failure it logs
/// and leaves `products` empty. Offline, a missing StoreKit configuration and a
/// product-id typo are therefore indistinguishable from here, so a
/// `.failed(Error)` case would be a fiction. The only honest signal is "there
/// is nothing to show", plus a way to try again.
enum PaywallLoadState: Equatable {
    case idle
    case loading
    /// Invariant: never empty. An empty catalog is `.unavailable`.
    case loaded([PlanOption])
    case unavailable
}

/// Every write-path outcome in one enum, so two mutually exclusive states can
/// never disagree (a separate `isRestoring` flag could be true while
/// `.purchasing` also held).
enum PaywallActionState: Equatable {
    case idle
    case purchasing(planID: String)
    case restoring
    /// Ask to Buy / SCA. Never collapsed into completed or cancelled.
    case pendingApproval
    /// The store said the purchase completed, but server truth has not flipped
    /// yet. This case is what enforces "never unlock optimistically".
    case awaitingEntitlement
    /// Server truth confirmed. The view dismisses on this.
    case unlocked
    /// Restore succeeded but surfaced no entitlement — not an error.
    case nothingToRestore
    /// Restore surfaced a real entitlement, but server truth has not flipped.
    /// Kept distinct from `.nothingToRestore`: telling a paying subscriber they
    /// own nothing because one refresh call failed is the worse of the two lies.
    case restoreUnconfirmed
    case failed(message: String)

    var isBusy: Bool {
        switch self {
        case .purchasing, .restoring: true
        default: false
        }
    }

    /// The store side is settled and only the server has yet to agree. A second
    /// purchase attempt here would risk charging someone who has already paid,
    /// so the Subscribe button stays down and Restore is the way forward.
    var isAwaitingServerTruth: Bool {
        switch self {
        case .awaitingEntitlement, .pendingApproval, .restoreUnconfirmed: true
        default: false
        }
    }
}

@MainActor
@Observable
final class PaywallViewModel {
    private(set) var loadState: PaywallLoadState = .idle
    private(set) var actionState: PaywallActionState = .idle
    var selectedPlanID: String?

    private let purchasing: any PaywallPurchasing

    init(purchasing: any PaywallPurchasing = LivePaywallPurchasing()) {
        self.purchasing = purchasing
    }

    // MARK: - Derived

    var plans: [PlanOption] {
        if case let .loaded(plans) = loadState {
            return plans
        }
        return []
    }

    var selectedPlan: PlanOption? {
        plans.first { $0.id == selectedPlanID }
    }

    var canPurchase: Bool {
        selectedPlan != nil && !actionState.isBusy && !actionState.isAwaitingServerTruth
    }

    var isUnlocked: Bool {
        actionState == .unlocked
    }

    var primaryButtonTitle: String {
        selectedPlan?.freeTrial != nil
            ? String(localized: "Start free trial")
            : String(localized: "Subscribe")
    }

    /// Inline status copy. The paywall is presented as a sheet from a sheet, and
    /// the root `ErrorToast` does not layer above modals — so every message here
    /// is rendered inline, never toasted.
    var statusMessage: String? {
        switch actionState {
        case .pendingApproval:
            String(localized: "Waiting for approval. Trays Plus unlocks as soon as it's approved.")
        case .awaitingEntitlement:
            String(localized: "Purchase complete. Finishing activation.")
        case .nothingToRestore:
            String(localized: "No active subscription found for this Apple ID.")
        case .restoreUnconfirmed:
            String(localized: "We found your subscription but couldn't confirm it yet. Try again in a moment.")
        case let .failed(message):
            message
        case .idle, .purchasing, .restoring, .unlocked:
            nil
        }
    }

    // MARK: - Load

    func load() async {
        guard loadState != .loading else { return }
        loadState = .loading
        let plans = await purchasing.loadPlans()
        guard !plans.isEmpty else {
            // Read path: log only, never toast (D95).
            paywallLog.error("Paywall catalog empty; showing unavailable state")
            loadState = .unavailable
            return
        }
        loadState = .loaded(plans)
        if selectedPlanID == nil || !plans.contains(where: { $0.id == selectedPlanID }) {
            // Default to the yearly plan when present: it is the cheaper option
            // per month, so defaulting there is the user-favourable default.
            selectedPlanID = plans.first(where: \.isYearly)?.id ?? plans.first?.id
        }
    }

    func retry() async {
        await load()
    }

    // MARK: - Purchase

    /// `appState` is read only AFTER the await returns. By then
    /// `SubscriptionService.purchase` → `syncEntitlement` → `refreshEntitlement`
    /// → `AppState.refreshCurrentUser()` has already run, so `isPlus` is server
    /// truth rather than an optimistic guess.
    func purchaseSelected(appState: AppState) async {
        guard !actionState.isBusy, let plan = selectedPlan else { return }
        actionState = .purchasing(planID: plan.id)
        do {
            let outcome = try await purchasing.purchase(planID: plan.id)
            switch outcome {
            case .completed:
                // `.completed` is returned even when the server did not accept
                // (SyncOutcome.alreadyInFlight), and refreshCurrentUser swallows
                // transient errors — so "completed" is NOT "entitled".
                actionState = appState.isPlus ? .unlocked : .awaitingEntitlement
            case .cancelled:
                actionState = .idle
            case .pending:
                actionState = .pendingApproval
            }
        } catch {
            actionState = Self.failureState(for: error, context: "purchase")
        }
    }

    // MARK: - Restore

    /// Three outcomes, not two. `SubscriptionService.restore()` calls
    /// `refreshEntitlement()` unconditionally and `AppState.refreshCurrentUser()`
    /// swallows transient errors, so `isPlus == false` after a successful restore
    /// is ambiguous. Branching on what the App Store actually surfaced is what
    /// stops a genuine subscriber with a flaky connection from being told,
    /// definitively, that they own nothing.
    func restore(appState: AppState) async {
        guard !actionState.isBusy else { return }
        actionState = .restoring
        do {
            let outcome = try await purchasing.restore()
            if appState.isPlus {
                actionState = .unlocked
            } else {
                actionState = outcome == .foundEntitlements ? .restoreUnconfirmed : .nothingToRestore
            }
        } catch {
            actionState = Self.failureState(for: error, context: "restore")
        }
    }

    /// Whether the status banner's dismiss control should render at all. Must
    /// stay in lockstep with the cases `dismissMessage()` handles: an X that
    /// does nothing is worse than no X, and it is exactly what the user is left
    /// staring at in `.awaitingEntitlement` / `.pendingApproval`, where the
    /// Subscribe button is also down.
    var isStatusDismissible: Bool {
        switch actionState {
        case .failed, .nothingToRestore, .restoreUnconfirmed: true
        default: false
        }
    }

    func dismissMessage() {
        guard isStatusDismissible else { return }
        actionState = .idle
    }

    // MARK: - Error mapping

    /// Maps a thrown error onto a user-facing state.
    ///
    /// The `StoreKitError.userCancelled` interception matters: `AppStore.sync()`
    /// throws it when the user dismisses the App Store credential prompt, and
    /// `SubscriptionError.from(_:)` has no StoreKit branch, so it would fall
    /// through to `.network` and tell someone who deliberately cancelled to
    /// "check your connection". Handled here rather than in W175's
    /// already-tested `from(_:)` so the service's behaviour is unchanged.
    private static func failureState(for error: Error, context: String) -> PaywallActionState {
        if let storeKitError = error as? StoreKitError, case .userCancelled = storeKitError {
            return .idle
        }
        let mapped = SubscriptionError.from(error)
        paywallLog.error("\(context, privacy: .public) failed: \(String(describing: mapped), privacy: .public)")
        let fallback = String(localized: "Something went wrong. Try again.")
        return .failed(message: mapped.errorDescription ?? fallback)
    }
}
