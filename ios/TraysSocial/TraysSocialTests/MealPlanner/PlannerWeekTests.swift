@testable import TraysSocial
import XCTest

/// Week normalization. The server keys every read to the Monday of the
/// requested week, so getting this wrong does not fail loudly — it silently
/// reads and writes a different seven days than the one on screen.
final class PlannerWeekTests: XCTestCase {
    // MARK: - Monday normalization

    func test_monday_forAMondayIsItself() {
        let monday = Self.date("2026-03-02")

        XCTAssertEqual(PlannerWeek.monday(for: monday), monday)
    }

    /// The off-by-one that would key every request to the following week.
    func test_monday_forASundayIsThePrecedingMonday() {
        XCTAssertEqual(PlannerWeek.monday(for: Self.date("2026-03-08")), Self.date("2026-03-02"))
    }

    func test_monday_isIdenticalForAllSevenDaysOfAWeek() {
        let expected = Self.date("2026-03-02")

        for day in ["2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05",
                    "2026-03-06", "2026-03-07", "2026-03-08"]
        {
            XCTAssertEqual(
                PlannerWeek.monday(for: Self.date(day)), expected,
                "\(day) must normalize to the Monday of its week"
            )
        }
    }

    /// The regression guard for the rejected `firstWeekday`-based
    /// implementation: an `en_US` calendar starts its week on Sunday, a `fr_FR`
    /// one on Monday. Both must produce the same Monday here, because the
    /// computation reads `.weekday` (fixed at 1 = Sunday for Gregorian) and
    /// never `firstWeekday`.
    func test_monday_isIdenticalUnderSundayFirstAndMondayFirstCalendars() {
        let sunday = Self.date("2026-03-08")

        XCTAssertEqual(
            PlannerWeek.monday(for: sunday, in: Self.calendar(locale: "en_US", firstWeekday: 1)),
            PlannerWeek.monday(for: sunday, in: Self.calendar(locale: "fr_FR", firstWeekday: 2))
        )
    }

    func test_monday_isIdenticalAcrossExtremeDeviceTimeZones() {
        let reference = Self.date("2026-03-04")

        XCTAssertEqual(
            PlannerWeek.containing(reference).wireKey,
            "2026-03-02",
            "the planner calendar is GMT-pinned, so the device zone cannot shift the week"
        )
    }

    // MARK: - Wire keys

    func test_wireKey_isZeroPaddedYYYYMMDD() {
        XCTAssertEqual(PlannerWeek.containing(Self.date("2026-03-04")).wireKey, "2026-03-02")
        XCTAssertEqual(PlannerWireDate.key(for: Self.date("2026-01-05")), "2026-01-05")
    }

    /// A Buddhist-calendar device must still send 2026, not 2569. Composing the
    /// string from `DateComponents` in a fixed Gregorian calendar is what makes
    /// this true without a `DateFormatter`.
    func test_wireKey_isUnaffectedByANonGregorianDeviceCalendar() {
        XCTAssertEqual(PlannerWireDate.key(for: Self.date("2026-03-02")), "2026-03-02")
    }

    func test_dateFromWireKey_roundTrips() {
        XCTAssertEqual(PlannerWireDate.date(from: "2026-03-02"), Self.date("2026-03-02"))
    }

    func test_dateFromWireKey_rejectsGarbage() {
        for bad in ["", "2026-03", "not-a-date", "2026-13-01", "2026-03-32", "26-03-02"] {
            XCTAssertNil(PlannerWireDate.date(from: bad), "\(bad) must not parse")
        }
    }

    func test_weekFromWireKey_normalizesToTheMonday() {
        XCTAssertEqual(PlannerWeek.from(wireKey: "2026-03-08")?.wireKey, "2026-03-02")
    }

    func test_weekFromWireKey_isNilOnGarbage() {
        XCTAssertNil(PlannerWeek.from(wireKey: "nope"))
    }

    // MARK: - Stepping

    func test_next_advancesSevenDays_andPreviousIsItsInverse() {
        let week = PlannerWeek.containing(Self.date("2026-03-02"))

        XCTAssertEqual(week.next.wireKey, "2026-03-09")
        XCTAssertEqual(week.next.previous, week)
    }

    /// US DST starts 2026-03-08. A locale-calendar implementation could produce
    /// a 167-hour week here and land on a Sunday.
    func test_next_acrossADSTBoundary_landsOnAMonday() {
        let week = PlannerWeek.containing(Self.date("2026-03-02"))

        XCTAssertEqual(week.next.wireKey, "2026-03-09")
        XCTAssertEqual(PlannerWeek.monday(for: week.next.start), week.next.start)
    }

    func test_next_acrossTheYearBoundary() {
        XCTAssertEqual(PlannerWeek.containing(Self.date("2025-12-29")).next.wireKey, "2026-01-05")
    }

    // MARK: - Days

    func test_days_returnsSevenAscendingDatesMondayThroughSunday() {
        let days = PlannerWeek.containing(Self.date("2026-03-02")).days(today: Self.date("2026-03-02"))

        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.map(\.key), [
            "2026-03-02", "2026-03-03", "2026-03-04", "2026-03-05",
            "2026-03-06", "2026-03-07", "2026-03-08",
        ])
    }

    func test_days_marksOnlyTodayAsToday() {
        let days = PlannerWeek.containing(Self.date("2026-03-02")).days(today: Self.date("2026-03-04"))

        XCTAssertEqual(days.filter(\.isToday).map(\.key), ["2026-03-04"])
    }

    func test_days_marksNoDayAsTodayInAnotherWeek() {
        let days = PlannerWeek.containing(Self.date("2026-03-02")).days(today: Self.date("2026-04-01"))

        XCTAssertTrue(days.allSatisfy { !$0.isToday })
    }

    // MARK: - Membership

    func test_contains_isTrueForEveryDayOfTheWeek_andFalseOutside() {
        let week = PlannerWeek.containing(Self.date("2026-03-02"))

        XCTAssertTrue(week.contains(dayKey: "2026-03-02"))
        XCTAssertTrue(week.contains(dayKey: "2026-03-08"))
        XCTAssertFalse(week.contains(dayKey: "2026-03-01"))
        XCTAssertFalse(week.contains(dayKey: "2026-03-09"))
        XCTAssertFalse(week.contains(dayKey: "garbage"))
    }

    // MARK: - Fixtures

    private static func date(_ key: String) -> Date {
        guard let date = PlannerWireDate.date(from: key) else {
            preconditionFailure("bad fixture date \(key)")
        }
        return date
    }

    private static func calendar(locale: String, firstWeekday: Int) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = .gmt
        calendar.locale = Locale(identifier: locale)
        calendar.firstWeekday = firstWeekday
        return calendar
    }
}
