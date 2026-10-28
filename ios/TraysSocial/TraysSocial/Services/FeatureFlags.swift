import Foundation
import OSLog

struct FeaturesPayload: Decodable, Sendable {
    let recipeFirst: Bool
    /// W209. Optional on the wire: a pre-W209 server omits it, and a required
    /// key would fail the whole decode and drop `recipeFirst` with it. Missing
    /// means off.
    let paidTier: Bool

    init(recipeFirst: Bool, paidTier: Bool = false) {
        self.recipeFirst = recipeFirst
        self.paidTier = paidTier
    }

    private enum CodingKeys: String, CodingKey {
        case recipeFirst
        case paidTier
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        recipeFirst = try container.decode(Bool.self, forKey: .recipeFirst)
        paidTier = try container.decodeIfPresent(Bool.self, forKey: .paidTier) ?? false
    }
}

/// Server-driven product flags from `GET /api/v1/features`. The last value is
/// cached in UserDefaults so a failed fetch never flips the shell back and
/// forth; a device that has never fetched sees the classic shell and no Trays
/// Plus entry points.
@MainActor
@Observable
final class FeatureFlags {
    static let shared = FeatureFlags()
    static let recipeFirstKey = "featureFlags.recipeFirst"
    static let paidTierKey = "featureFlags.paidTier"
    private static let log = Logger(subsystem: "com.trays.social", category: "features")

    private let defaults: UserDefaults
    private(set) var recipeFirst: Bool
    /// W209. Mirrors the server's `FEATURES_PAID_TIER`. Off hides every Plus
    /// entry point; it is never an access control (the server still enforces
    /// the entitlement on every gated endpoint).
    private(set) var paidTier: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recipeFirst = defaults.bool(forKey: Self.recipeFirstKey)
        paidTier = defaults.bool(forKey: Self.paidTierKey)
    }

    func apply(_ payload: FeaturesPayload) {
        recipeFirst = payload.recipeFirst
        paidTier = payload.paidTier
        defaults.set(payload.recipeFirst, forKey: Self.recipeFirstKey)
        defaults.set(payload.paidTier, forKey: Self.paidTierKey)
    }

    /// Read path: a failure logs and keeps the cached value, never toasts (D95).
    func refresh() async {
        do {
            let response: DataResponse<FeaturesPayload> = try await APIClient.shared.get(path: "/features")
            apply(response.data)
        } catch {
            Self.log.error("features refresh failed: \(String(describing: error), privacy: .public)")
        }
    }
}

/// W209. Whether the Trays Plus entry points render. Pure, like `ShellLayout`
/// and `PlannerEntryMode`, because the project has no view-test infrastructure.
enum PlusVisibility {
    static func showsPlus(paidTier: Bool) -> Bool {
        paidTier
    }

    /// My Tray's W177/W178 empty-state guard with the Plus inputs masked while
    /// Plus is hidden: collections or a plan the user cannot see must not hold
    /// back the empty state and leave a blank tray.
    static func showsTrayEmptyState(
        paidTier: Bool,
        trayIsEmpty: Bool,
        hasCollections: Bool,
        hasAnyEntries: Bool,
        isLoadingWeek: Bool
    ) -> Bool {
        guard trayIsEmpty else { return false }
        guard showsPlus(paidTier: paidTier) else { return true }
        return !hasCollections && !hasAnyEntries && !isLoadingWeek
    }
}
