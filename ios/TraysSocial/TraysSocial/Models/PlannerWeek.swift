import Foundation

/// Converts between `Date` and the bare `YYYY-MM-DD` strings the meal-plan API
/// speaks, without a `DateFormatter`.
///
/// No formatter, deliberately. `DateFormatter` is not `Sendable`, so under Swift
/// 6 language mode a cached `static let` one does not compile, and the escapes
/// are both worse than the arithmetic: `@MainActor static let` would infect
/// every caller of `PlannerWeek.wireKey` with actor isolation, and
/// `nonisolated(unsafe)` would be a lie about a mutable-state type. Composing
/// the string from `DateComponents` is also immune to the two classic
/// formatter bugs — forgetting `en_US_POSIX` (locale-dependent digits) and a
/// non-Gregorian device calendar (a Buddhist-calendar device would otherwise
/// send year 2569).
enum PlannerWireDate {
    /// `YYYY-MM-DD` in the planner's fixed GMT Gregorian calendar.
    static func key(for date: Date, in calendar: Calendar = PlannerWeek.calendar) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: date)
        return String(format: "%04d-%02d-%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
    }

    /// Parses a server `YYYY-MM-DD` back to GMT midnight. Returns nil on
    /// anything else — the caller falls back to the current week rather than
    /// guessing.
    static func date(from key: String) -> Date? {
        let parts = key.split(separator: "-", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let year = Int(parts[0]), let month = Int(parts[1]), let day = Int(parts[2]),
              parts[0].count == 4, (1 ... 12).contains(month), (1 ... 31).contains(day)
        else {
            return nil
        }
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        return PlannerWeek.calendar.date(from: components)
    }
}

/// One rendered day column in the week view.
///
/// The labels are stored, not computed: `days()` builds them once per week
/// change, because SwiftUI re-evaluates `body` constantly and two format calls
/// per day per pass is 14 formats a frame for text that cannot change until the
/// week does.
struct PlannerDay: Identifiable, Hashable, Sendable {
    /// GMT midnight of this day.
    let date: Date
    /// The `YYYY-MM-DD` value sent as `date` when planning a recipe. Note the
    /// server stores this exact day — only *week* reads get normalized.
    let key: String
    /// Locale-aware short weekday ("Mon" / "lun.").
    let weekdayLabel: String
    /// Locale-aware day number ("2").
    let dayNumberLabel: String
    let isToday: Bool

    var id: String {
        key
    }
}

/// A Monday-anchored 7-day window, matching the server's canonical week.
///
/// The whole type exists so the Monday rule has exactly one implementation and
/// that implementation has no locale input at all — see `monday(for:in:)`.
struct PlannerWeek: Hashable, Sendable {
    /// GMT midnight of the Monday that starts this week.
    let start: Date

    /// Fixed Gregorian/GMT calendar. Never `Calendar.current`.
    ///
    /// GMT is load-bearing, not cosmetic: the API's dates are bare calendar
    /// days with no zone attached. A device at UTC+13 taking `startOfDay`
    /// locally produces an instant that renders as the *previous* day once
    /// formatted in GMT, so its whole week would be keyed one day early.
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }()

    private static let weekdayStyle = Date.FormatStyle(date: .omitted, time: .omitted, timeZone: .gmt)
        .weekday(.abbreviated)
    private static let dayNumberStyle = Date.FormatStyle(date: .omitted, time: .omitted, timeZone: .gmt)
        .day(.defaultDigits)
    private static let rangeStyle = Date.FormatStyle(date: .abbreviated, time: .omitted, timeZone: .gmt)

    /// The Monday on or before `date`, in `calendar`.
    ///
    /// Deliberately arithmetic on `.weekday` rather than
    /// `dateInterval(of: .weekOfYear:)` or `calendar.firstWeekday`. Those two
    /// give the right answer only if the caller remembers to override
    /// `firstWeekday`, and forgetting is silent: an `en_US` device (firstWeekday
    /// = Sunday) would key every request to a window the server never uses.
    /// `.weekday` is fixed at 1 = Sunday for the Gregorian calendar regardless
    /// of locale, so this computation has no locale input to get wrong.
    ///
    /// `calendar` is a parameter purely so tests can prove that claim by
    /// passing Sunday-first and Monday-first calendars and getting one answer.
    static func monday(for date: Date, in calendar: Calendar = PlannerWeek.calendar) -> Date {
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offsetFromMonday = (weekday + 5) % 7
        return calendar.date(byAdding: .day, value: -offsetFromMonday, to: day) ?? day
    }

    static func containing(_ date: Date) -> PlannerWeek {
        PlannerWeek(start: monday(for: date))
    }

    static var current: PlannerWeek {
        containing(Date())
    }

    /// Rebuilds a week from the server's echoed `week_start`. Nil on a value we
    /// cannot parse, so the caller keeps the week it already computed.
    static func from(wireKey: String) -> PlannerWeek? {
        guard let date = PlannerWireDate.date(from: wireKey) else { return nil }
        return containing(date)
    }

    /// The `week_start` query/body value. Always a Monday.
    var wireKey: String {
        PlannerWireDate.key(for: start)
    }

    /// Sunday of this week. The server's window is `[monday, monday + 6]`.
    var endInclusive: Date {
        Self.calendar.date(byAdding: .day, value: 6, to: start) ?? start
    }

    /// Stepping by 7 days rather than `.weekOfYear` keeps the step independent
    /// of `firstWeekday` too, and the GMT calendar means DST never shortens it.
    var next: PlannerWeek {
        PlannerWeek(start: Self.calendar.date(byAdding: .day, value: 7, to: start) ?? start)
    }

    var previous: PlannerWeek {
        PlannerWeek(start: Self.calendar.date(byAdding: .day, value: -7, to: start) ?? start)
    }

    var isCurrent: Bool {
        self == Self.current
    }

    /// "Mar 2 – Mar 8", localized per endpoint.
    var rangeLabel: String {
        "\(start.formatted(Self.rangeStyle)) – \(endInclusive.formatted(Self.rangeStyle))"
    }

    /// Monday through Sunday, chronological.
    ///
    /// Deliberately NOT rotated to the device's `firstWeekday`. Leading an
    /// `en_US` user's row with Sunday would put *this week's* Sunday
    /// (`monday + 6`) in front of `monday + 0`, so the dates would read
    /// 8, 2, 3, 4, 5, 6, 7 — the server's window has no earlier Sunday to lead
    /// with. Locale-awareness therefore lives in the labels, not the ordering.
    func days(today: Date = Date()) -> [PlannerDay] {
        let todayKey = PlannerWireDate.key(for: today)
        return (0 ..< 7).map { offset in
            let date = Self.calendar.date(byAdding: .day, value: offset, to: start) ?? start
            let key = PlannerWireDate.key(for: date)
            return PlannerDay(
                date: date,
                key: key,
                weekdayLabel: date.formatted(Self.weekdayStyle),
                dayNumberLabel: date.formatted(Self.dayNumberStyle),
                isToday: key == todayKey
            )
        }
    }

    /// Whether a `YYYY-MM-DD` day belongs to this week. Guards a replayed
    /// plan-intent from landing on a day that is no longer on screen.
    func contains(dayKey: String) -> Bool {
        guard let date = PlannerWireDate.date(from: dayKey) else { return false }
        return Self.monday(for: date) == start
    }
}
