@testable import TraysSocial
import XCTest

final class ShellLayoutTests: XCTestCase {
    func test_decide() {
        XCTAssertEqual(ShellLayout.decide(recipeFirst: false), .classic)
        XCTAssertEqual(ShellLayout.decide(recipeFirst: true), .recipeFirst)
    }

    func test_tabsAndInitialTab() {
        XCTAssertEqual(ShellLayout.classic.tabs, [.feed, .myTray, .find])
        XCTAssertEqual(ShellLayout.recipeFirst.tabs, [.home, .myTray, .search])
        XCTAssertEqual(ShellLayout.classic.initialTab, .myTray)
        XCTAssertEqual(ShellLayout.recipeFirst.initialTab, .home)
    }

    func test_normalizeMapsTabsAcrossLayouts() {
        XCTAssertEqual(ShellLayout.recipeFirst.normalize(.feed), .home)
        XCTAssertEqual(ShellLayout.recipeFirst.normalize(.find), .search)
        XCTAssertEqual(ShellLayout.recipeFirst.normalize(.myTray), .myTray)
        XCTAssertEqual(ShellLayout.classic.normalize(.home), .feed)
        XCTAssertEqual(ShellLayout.classic.normalize(.search), .find)
        XCTAssertEqual(ShellLayout.classic.normalize(.find), .find)
    }

    func test_tabAfterLaunchFetch() {
        // Flag turned on since the last launch: an untouched opening tab lands on Home.
        XCTAssertEqual(ShellLayout.recipeFirst.tabAfterLaunchFetch(from: .classic, current: .myTray), .home)
        // A tab the user moved to is mapped, not reset.
        XCTAssertEqual(ShellLayout.recipeFirst.tabAfterLaunchFetch(from: .classic, current: .find), .search)
        // Flag turned off: Home (or its normalized twin, Feed) returns to My Tray.
        XCTAssertEqual(ShellLayout.classic.tabAfterLaunchFetch(from: .recipeFirst, current: .home), .myTray)
        XCTAssertEqual(ShellLayout.classic.tabAfterLaunchFetch(from: .recipeFirst, current: .feed), .myTray)
        XCTAssertEqual(ShellLayout.classic.tabAfterLaunchFetch(from: .recipeFirst, current: .myTray), .myTray)
        XCTAssertEqual(ShellLayout.classic.tabAfterLaunchFetch(from: .recipeFirst, current: .search), .find)
        // No change in layout: the current tab is kept.
        XCTAssertEqual(ShellLayout.classic.tabAfterLaunchFetch(from: .classic, current: .feed), .feed)
        XCTAssertEqual(ShellLayout.recipeFirst.tabAfterLaunchFetch(from: .recipeFirst, current: .search), .search)
    }
}
