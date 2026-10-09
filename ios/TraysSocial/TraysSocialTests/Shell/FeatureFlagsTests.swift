@testable import TraysSocial
import XCTest

@MainActor
final class FeatureFlagsTests: XCTestCase {
    private let suite = "FeatureFlagsTests"

    /// A wiped suite per test. Not `setUp()`: overriding the nonisolated
    /// XCTest hook from a `@MainActor` class does not compile under Swift 6.
    private func freshDefaults() -> UserDefaults {
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return defaults
    }

    func test_neverFetchedMeansClassicShell() {
        XCTAssertFalse(FeatureFlags(defaults: freshDefaults()).recipeFirst)
        XCTAssertEqual(ShellLayout.decide(recipeFirst: FeatureFlags(defaults: freshDefaults()).recipeFirst), .classic)
    }

    func test_applyUpdatesAndPersistsAcrossLaunches() {
        let defaults = freshDefaults()
        let flags = FeatureFlags(defaults: defaults)
        flags.apply(FeaturesPayload(recipeFirst: true))
        XCTAssertTrue(flags.recipeFirst)
        // A later launch whose fetch fails still sees the cached value.
        XCTAssertTrue(FeatureFlags(defaults: defaults).recipeFirst)

        flags.apply(FeaturesPayload(recipeFirst: false))
        XCTAssertFalse(FeatureFlags(defaults: defaults).recipeFirst)
        defaults.removePersistentDomain(forName: suite)
    }

    func test_decodesServerPayload() throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let response = try decoder.decode(
            DataResponse<FeaturesPayload>.self, from: Data(#"{"data": {"recipe_first": true}}"#.utf8)
        )
        XCTAssertTrue(response.data.recipeFirst)
    }
}
