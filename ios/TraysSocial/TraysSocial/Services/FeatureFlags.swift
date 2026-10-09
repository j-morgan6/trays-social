import Foundation
import OSLog

struct FeaturesPayload: Decodable, Sendable {
    let recipeFirst: Bool
}

/// Server-driven product flags from `GET /api/v1/features`. The last value is
/// cached in UserDefaults so a failed fetch never flips the shell back and
/// forth; a device that has never fetched sees the classic shell.
@MainActor
@Observable
final class FeatureFlags {
    static let shared = FeatureFlags()
    static let recipeFirstKey = "featureFlags.recipeFirst"
    private static let log = Logger(subsystem: "com.trays.social", category: "features")

    private let defaults: UserDefaults
    private(set) var recipeFirst: Bool

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        recipeFirst = defaults.bool(forKey: Self.recipeFirstKey)
    }

    func apply(_ payload: FeaturesPayload) {
        recipeFirst = payload.recipeFirst
        defaults.set(payload.recipeFirst, forKey: Self.recipeFirstKey)
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
