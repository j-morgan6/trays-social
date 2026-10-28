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
    /// W213. Whether this binary's privacy manifest declares purchase data.
    private let purchaseDataDeclared: Bool
    private(set) var recipeFirst: Bool
    /// W209. Mirrors the server's `FEATURES_PAID_TIER`. Off hides every Plus
    /// entry point; it is never an access control (the server still enforces
    /// the entitlement on every gated endpoint).
    ///
    /// W213. Also off, whatever the server says, in a build whose bundled
    /// PrivacyInfo.xcprivacy does not declare Purchase History: Plus sends App
    /// Store transactions to the server, so turning the flag on must not make
    /// an installed build's privacy declaration false. Every Plus surface and
    /// the StoreKit entitlement sync (D119) read this value.
    private(set) var paidTier: Bool

    init(
        defaults: UserDefaults = .standard,
        purchaseDataDeclared: Bool = PrivacyDeclaration.bundleDeclaresPurchaseHistory()
    ) {
        self.defaults = defaults
        self.purchaseDataDeclared = purchaseDataDeclared
        recipeFirst = defaults.bool(forKey: Self.recipeFirstKey)
        paidTier = purchaseDataDeclared && defaults.bool(forKey: Self.paidTierKey)
    }

    func apply(_ payload: FeaturesPayload) {
        recipeFirst = payload.recipeFirst
        paidTier = purchaseDataDeclared && payload.paidTier
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

/// W213. Reads the bundled privacy manifest. The Plus release adds Purchase
/// History to PrivacyInfo.xcprivacy, which lifts the `paidTier` guard above
/// with no other code change.
enum PrivacyDeclaration {
    static let purchaseHistoryType = "NSPrivacyCollectedDataTypePurchaseHistory"

    /// False for a missing or unreadable manifest: when in doubt, Plus stays off.
    static func declaresPurchaseHistory(manifest data: Data?) -> Bool {
        guard let data,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil),
              let root = plist as? [String: Any],
              let types = root["NSPrivacyCollectedDataTypes"] as? [[String: Any]]
        else { return false }
        return types.contains { $0["NSPrivacyCollectedDataType"] as? String == purchaseHistoryType }
    }

    static func bundleDeclaresPurchaseHistory(_ bundle: Bundle = .main) -> Bool {
        let data = bundle.url(forResource: "PrivacyInfo", withExtension: "xcprivacy")
            .flatMap { try? Data(contentsOf: $0) }
        return declaresPurchaseHistory(manifest: data)
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
