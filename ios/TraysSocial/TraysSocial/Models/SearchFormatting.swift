import Foundation

/// W243: the summary card over ingredient results (Main artboard, Search
/// state c). Pure so the wording can be unit tested.
enum IngredientSummary {
    /// "With chicken and rice, you can make…" for up to three ingredients,
    /// "With your 5 ingredients" past that.
    static func title(chips: [String], locale: Locale = .current) -> String {
        if chips.count > 3 {
            return String(localized: "With your \(chips.count) ingredients")
        }
        let formatter = ListFormatter()
        formatter.locale = locale
        let list = formatter.string(from: chips) ?? chips.joined(separator: ", ")
        return String(localized: "With \(list), you can make…")
    }

    /// "2 ready now · 3 almost there", or "Nothing complete yet · 3 almost there".
    static func subtitle(ready: Int, almost: Int) -> String {
        let readyPart = ready > 0
            ? String(localized: "\(ready) ready now")
            : String(localized: "Nothing complete yet")
        let almostPart = String(localized: "\(almost) almost there")
        return "\(readyPart) · \(almostPart)"
    }
}

/// W243: the "Uses chicken, rice" line on a "You have everything" row: the
/// searched ingredients this recipe lists, in chip order. A chip counts when
/// an ingredient name contains it, ignoring case.
enum IngredientUses {
    static func line(chips: [String], in ingredients: [Ingredient]) -> String? {
        let names = ingredients.map { $0.name.lowercased() }
        let used = chips.filter { chip in
            let needle = chip.lowercased()
            return names.contains { $0.contains(needle) }
        }
        guard !used.isEmpty else { return nil }
        return String(localized: "Uses \(used.joined(separator: ", "))")
    }
}

/// W243: Browse tiles cycle three warm fills (Components artboard,
/// "Category tile"): cream, amber-muted, mint tint.
enum CategoryTileFill: Equatable {
    case cream
    case amber
    case mint

    static func at(_ index: Int) -> CategoryTileFill {
        switch abs(index) % 3 {
        case 0: .cream
        case 1: .amber
        default: .mint
        }
    }
}

/// W243: Browse failed when a load has been attempted, finished, and left
/// nothing to show. Retry flips back to loading while the new load runs.
enum SearchBrowseState {
    static func failed(attempted: Bool, hasBrowse: Bool, isLoading: Bool) -> Bool {
        attempted && !hasBrowse && !isLoading
    }
}

/// W243: Most saved shows a "#n" badge on its first three recipes. Ads are
/// skipped when counting, so the badge follows recipe order, not grid order.
enum MostSavedRank {
    static let badged = 3

    /// Rank (1-based) of each post id among the posts in `items`, for the
    /// first `badged` posts only.
    static func ranks(postIDs: [Int]) -> [Int: Int] {
        var ranks: [Int: Int] = [:]
        for (offset, id) in postIDs.prefix(badged).enumerated() {
            ranks[id] = offset + 1
        }
        return ranks
    }
}
