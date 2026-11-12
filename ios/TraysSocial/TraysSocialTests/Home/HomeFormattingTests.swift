@testable import TraysSocial
import XCTest

/// W241: the pure helpers behind the redesigned Home (greeting, New badge,
/// cook time).
final class HomeFormattingTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC") ?? .current
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    /// 2026-11-12 is a Thursday.
    private func date(day: Int = 12, hour: Int, minute: Int = 0) -> Date {
        let parts = DateComponents(year: 2026, month: 11, day: day, hour: hour, minute: minute)
        return calendar.date(from: parts) ?? Date()
    }

    func test_kickerNamesTheWeekdayAndPartOfDay() {
        XCTAssertEqual(HomeGreeting.kicker(now: date(hour: 8), calendar: calendar), "Thursday morning")
        XCTAssertEqual(HomeGreeting.kicker(now: date(hour: 13), calendar: calendar), "Thursday afternoon")
        XCTAssertEqual(HomeGreeting.kicker(now: date(hour: 19), calendar: calendar), "Thursday evening")
        XCTAssertEqual(HomeGreeting.kicker(now: date(hour: 23, minute: 30), calendar: calendar), "Thursday night")
        XCTAssertEqual(HomeGreeting.kicker(now: date(day: 15, hour: 9), calendar: calendar), "Sunday morning")
    }

    func test_dayPartBoundaries() {
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 4), .night)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 5), .morning)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 11), .morning)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 12), .afternoon)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 16), .afternoon)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 17), .evening)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 21), .evening)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 22), .night)
        XCTAssertEqual(HomeGreeting.DayPart.of(hour: 0), .night)
    }

    func test_questionUsesTheUsernameWhenThereIsOne() {
        XCTAssertEqual(HomeGreeting.question(username: "ren"), "What are you cooking, ren?")
        XCTAssertEqual(HomeGreeting.question(username: nil), "What are you cooking?")
        XCTAssertEqual(HomeGreeting.question(username: ""), "What are you cooking?")
    }

    func test_newBadgeLastsLessThanADay() {
        let now = date(hour: 12)
        let justUnder = now.addingTimeInterval(-(RecipeFreshness.newWindow - 1))
        let exactly = now.addingTimeInterval(-RecipeFreshness.newWindow)
        XCTAssertTrue(RecipeFreshness.isNew(insertedAt: justUnder, now: now))
        XCTAssertFalse(RecipeFreshness.isNew(insertedAt: exactly, now: now))
        XCTAssertTrue(RecipeFreshness.isNew(insertedAt: now.addingTimeInterval(60), now: now))
    }

    func test_cookTimeLabel() {
        XCTAssertNil(CookTime.label(minutes: nil))
        XCTAssertNil(CookTime.label(minutes: 0))
        XCTAssertEqual(CookTime.label(minutes: 25), "25 min")
        XCTAssertEqual(CookTime.label(minutes: 60), "1 hr")
        XCTAssertEqual(CookTime.label(minutes: 90), "1 hr 30 min")
    }
}
