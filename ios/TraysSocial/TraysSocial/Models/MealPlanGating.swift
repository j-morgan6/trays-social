import Foundation

/// A plan the user was trying to make when the paywall interrupted them.
struct PlannedIntent: Equatable, Sendable {
    let dayKey: String
    let post: Post
}

/// What a failed meal-plan *write* should do.
///
/// Extracted as a pure static for the same reason `CollectionWriteOutcome` and
/// `PlusGateOutcome` were: this project has no view-test or network-mock
/// infrastructure, so a decision left inline in a `catch` is asserted by
/// nothing — and this one decides whether a lapsed subscriber sees the paywall
/// or a dead-end error toast.
///
/// The meal-plan API returns three different 403/422 shapes that look alike
/// from a distance, and only one of them is a sales moment:
/// - 403 with `code: "subscription_required"` — entitlement lapsed. Paywall.
/// - 403 with no code — the recipe is neither owned nor bookmarked. Toast; a
///   paywall here would sell a subscription that does not fix the problem.
/// - 422 — the day/recipe pair is already planned (the DB unique index). Toast.
enum MealPlanWriteOutcome: Equatable {
    case presentPaywall
    case toast

    static func decide(for error: Error) -> MealPlanWriteOutcome {
        guard let api = error as? APIError, case .subscriptionRequired = api else {
            return .toast
        }
        return .presentPaywall
    }
}

/// How the "Plan your week" row in My Tray behaves.
///
/// Acceptance criteria 1 and 5 pull in opposite directions: AC 1 wants free
/// users sent to the paywall, AC 5 wants a lapsed subscriber to still read the
/// plan they already built. A hard gate satisfies the first and breaks the
/// second — it strands an existing plan behind a wall, which is verbatim the
/// unreachable-content bug W177's review round caught for collections.
///
/// Resolution: gate the row only for users who have nothing to read. The server
/// agrees — `GET /meal-plan` is never gated, only `POST /entries` is — so an
/// open row can never show content the user is not entitled to see.
enum PlannerEntryMode: Equatable {
    /// Navigate straight in.
    case open
    /// Route through the paywall.
    case gated

    static func decide(isPlus: Bool, hasPlan: Bool) -> PlannerEntryMode {
        isPlus || hasPlan ? .open : .gated
    }
}

/// Client-side pre-checks for planning a recipe. The server stays
/// authoritative; these exist so the two predictable rejections never cost a
/// round trip or an optimistic card that vanishes a second later.
enum PlanValidation: Equatable {
    case valid
    /// Mirrors `unique_index(:meal_plan_entries, [:user_id, :date, :post_id])`.
    case duplicate
    /// The target day is not in the week on screen — a replayed intent whose
    /// week moved while the paywall was up.
    case outsideWeek

    var message: String? {
        switch self {
        case .valid: nil
        case .duplicate: String(localized: "That recipe is already planned for this day.")
        case .outsideWeek: String(localized: "That day is no longer in view.")
        }
    }
}
