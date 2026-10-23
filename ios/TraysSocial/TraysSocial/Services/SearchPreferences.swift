import Foundation

/// Per-device search conveniences: recently used ingredient chips. Plain
/// UserDefaults, like `apnsDeviceToken`; nothing here is account data, so it
/// survives sign-out on purpose.
struct SearchPreferences {
    /// W205 removed the Recipes / What I have switch that this key remembered.
    static let legacyModeKey = "search.mode"
    static let recentIngredientsKey = "search.recentIngredients"
    static let maxRecent = 10

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Drops the stored mode left behind by builds before W205.
    func removeLegacyMode() {
        defaults.removeObject(forKey: Self.legacyModeKey)
    }

    var recentIngredients: [String] {
        defaults.stringArray(forKey: Self.recentIngredientsKey) ?? []
    }

    /// Most recent first, unique, capped at `maxRecent`.
    func recordRecent(_ terms: [String]) {
        var merged: [String] = []
        for term in terms + recentIngredients where !merged.contains(term) {
            merged.append(term)
        }
        defaults.set(Array(merged.prefix(Self.maxRecent)), forKey: Self.recentIngredientsKey)
    }
}
