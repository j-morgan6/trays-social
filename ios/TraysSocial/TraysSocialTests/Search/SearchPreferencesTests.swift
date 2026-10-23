@testable import TraysSocial
import XCTest

final class SearchPreferencesTests: XCTestCase {
    private var defaults: UserDefaults!
    private let suite = "SearchPreferencesTests"

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
        super.tearDown()
    }

    /// W205 removed the Recipes / What I have switch; its stored mode is
    /// dropped and recently used chips survive.
    func test_removeLegacyModeKeepsRecentIngredients() {
        defaults.set("whatIHave", forKey: SearchPreferences.legacyModeKey)
        let prefs = SearchPreferences(defaults: defaults)
        prefs.recordRecent(["eggs"])

        prefs.removeLegacyMode()

        XCTAssertNil(defaults.object(forKey: SearchPreferences.legacyModeKey))
        XCTAssertEqual(prefs.recentIngredients, ["eggs"])
    }

    func test_recentIngredientsAreMostRecentFirstUniqueAndCapped() {
        let prefs = SearchPreferences(defaults: defaults)
        prefs.recordRecent(["eggs", "rice"])
        prefs.recordRecent(["spinach", "eggs"])
        XCTAssertEqual(prefs.recentIngredients, ["spinach", "eggs", "rice"])

        prefs.recordRecent((1 ... 12).map { "item\($0)" })
        XCTAssertEqual(prefs.recentIngredients.count, SearchPreferences.maxRecent)
        XCTAssertEqual(prefs.recentIngredients.first, "item1")
    }
}
