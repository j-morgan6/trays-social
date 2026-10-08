import Foundation

enum SearchMode: String, CaseIterable, Sendable {
    case recipes
    case whatIHave
}

/// Per-device search conveniences: the last mode used and recently used
/// ingredient chips. Plain UserDefaults, like `apnsDeviceToken`; nothing here
/// is account data, so it survives sign-out on purpose.
struct SearchPreferences {
    static let modeKey = "search.mode"
    static let recentIngredientsKey = "search.recentIngredients"
    static let maxRecent = 10

    let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    var mode: SearchMode {
        get { defaults.string(forKey: Self.modeKey).flatMap(SearchMode.init(rawValue:)) ?? .recipes }
        nonmutating set { defaults.set(newValue.rawValue, forKey: Self.modeKey) }
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
