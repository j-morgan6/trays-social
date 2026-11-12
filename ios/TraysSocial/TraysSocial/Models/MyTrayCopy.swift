import Foundation

/// W245: the counted copy on My Tray, a collection and the planner card. Pure,
/// so the wording is tested without a view.
enum MyTrayCopy {
    /// "7 recipes · 8 saved", or the new-user line when the tray is empty.
    static func headerSubtitle(recipes: Int, saved: Int) -> String {
        guard recipes > 0 || saved > 0 else {
            return String(localized: "Recipes you post and save live here.")
        }
        return [recipeCount(recipes), String(localized: "\(saved) saved")].joined(separator: " · ")
    }

    /// "No recipes yet", "1 recipe" or "N recipes".
    static func recipeCount(_ count: Int) -> String {
        switch count {
        case 0: String(localized: "No recipes yet")
        case 1: String(localized: "1 recipe")
        default: String(localized: "\(count) recipes")
        }
    }

    /// A collection's line under its name. The count is only known once every
    /// page has loaded, so a partial list says only who can see it.
    static func collectionSubtitle(count: Int?) -> String {
        let privacy = String(localized: "Only you can see this")
        guard let count else { return privacy }
        return [recipeCount(count), privacy].joined(separator: " · ")
    }

    /// The planner card's summary under its title.
    static func planSummary(plannedDays: Int, totalDays: Int) -> String {
        switch plannedDays {
        case 0: String(localized: "Nothing planned yet. Pick a dinner for each day.")
        case totalDays: String(localized: "Every dinner this week is planned.")
        default: String(localized: "\(plannedDays) of \(totalDays) dinners planned.")
        }
    }
}
