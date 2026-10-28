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

    /// W213. Flags for a build whose manifest declares purchase data (the
    /// Plus release), so the paid_tier tests exercise the server flag alone.
    private func plusBuildFlags(_ defaults: UserDefaults) -> FeatureFlags {
        FeatureFlags(defaults: defaults, purchaseDataDeclared: true)
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

    // MARK: - W209 paid_tier

    func test_neverFetchedMeansPlusHidden() {
        let flags = FeatureFlags(defaults: freshDefaults())
        XCTAssertFalse(flags.paidTier)
        XCTAssertFalse(PlusVisibility.showsPlus(paidTier: flags.paidTier))
    }

    func test_paidTierPersistsAcrossLaunches() {
        let defaults = freshDefaults()
        let flags = plusBuildFlags(defaults)
        flags.apply(FeaturesPayload(recipeFirst: true, paidTier: true))
        XCTAssertTrue(flags.paidTier)
        // A later launch whose fetch fails keeps the cached value, and the two
        // flags are cached independently.
        let relaunched = plusBuildFlags(defaults)
        XCTAssertTrue(relaunched.paidTier)
        XCTAssertTrue(relaunched.recipeFirst)

        flags.apply(FeaturesPayload(recipeFirst: true, paidTier: false))
        XCTAssertFalse(plusBuildFlags(defaults).paidTier)
        XCTAssertTrue(plusBuildFlags(defaults).recipeFirst)
        defaults.removePersistentDomain(forName: suite)
    }

    func test_decodesPayloadWithoutPaidTierAsOff() throws {
        let response = try decode(#"{"data": {"recipe_first": true}}"#)
        XCTAssertTrue(response.data.recipeFirst)
        XCTAssertFalse(response.data.paidTier)
    }

    func test_decodesPaidTierFromServerPayload() throws {
        let response = try decode(#"{"data": {"recipe_first": false, "paid_tier": true}}"#)
        XCTAssertFalse(response.data.recipeFirst)
        XCTAssertTrue(response.data.paidTier)
    }

    func test_plusVisibilityFollowsPaidTier() {
        XCTAssertTrue(PlusVisibility.showsPlus(paidTier: true))
        XCTAssertFalse(PlusVisibility.showsPlus(paidTier: false))
    }

    func test_trayEmptyStateIgnoresPlusStateWhenPaidTierOff() {
        XCTAssertTrue(PlusVisibility.showsTrayEmptyState(
            paidTier: false, trayIsEmpty: true,
            hasCollections: true, hasAnyEntries: true, isLoadingWeek: true
        ))
    }

    func test_trayEmptyStateKeepsW177W178GuardWhenPaidTierOn() {
        func shows(_ collections: Bool, _ entries: Bool, _ loading: Bool) -> Bool {
            PlusVisibility.showsTrayEmptyState(
                paidTier: true, trayIsEmpty: true,
                hasCollections: collections, hasAnyEntries: entries, isLoadingWeek: loading
            )
        }
        XCTAssertTrue(shows(false, false, false))
        XCTAssertFalse(shows(true, false, false))
        XCTAssertFalse(shows(false, true, false))
        XCTAssertFalse(shows(false, false, true))
    }

    func test_trayEmptyStateHiddenWhenTrayHasContent() {
        for paidTier in [true, false] {
            XCTAssertFalse(PlusVisibility.showsTrayEmptyState(
                paidTier: paidTier, trayIsEmpty: false,
                hasCollections: false, hasAnyEntries: false, isLoadingWeek: false
            ))
        }
    }

    /// Edge case "flag flips between launches while a planner or collection
    /// sheet is open": the in-memory flag follows each fetch, and stale Plus
    /// state loaded before a flip to off no longer holds back the empty state.
    /// What an already-open sheet does is a view-lifecycle question with no
    /// view-test infrastructure here, so it stays on the manual tests.
    func test_midSessionFlipOffHidesPlusAndRestoresEmptyState() {
        let defaults = freshDefaults()
        let flags = plusBuildFlags(defaults)
        flags.apply(FeaturesPayload(recipeFirst: false, paidTier: true))
        XCTAssertFalse(PlusVisibility.showsTrayEmptyState(
            paidTier: flags.paidTier, trayIsEmpty: true,
            hasCollections: true, hasAnyEntries: true, isLoadingWeek: false
        ))

        flags.apply(FeaturesPayload(recipeFirst: false, paidTier: false))
        XCTAssertFalse(PlusVisibility.showsPlus(paidTier: flags.paidTier))
        XCTAssertTrue(PlusVisibility.showsTrayEmptyState(
            paidTier: flags.paidTier, trayIsEmpty: true,
            hasCollections: true, hasAnyEntries: true, isLoadingWeek: false
        ))
        defaults.removePersistentDomain(forName: suite)
    }

    // MARK: - W213 purchase-data guard

    /// The server flag alone cannot turn Plus on in a build whose privacy
    /// manifest declares no purchase data, either live or from the cache.
    func test_paidTierStaysOffWhenPurchaseDataIsUndeclared() {
        let defaults = freshDefaults()
        let flags = FeatureFlags(defaults: defaults, purchaseDataDeclared: false)
        flags.apply(FeaturesPayload(recipeFirst: true, paidTier: true))
        XCTAssertFalse(flags.paidTier)
        XCTAssertTrue(flags.recipeFirst)
        XCTAssertFalse(FeatureFlags(defaults: defaults, purchaseDataDeclared: false).paidTier)
        // The server value is still cached, so the Plus build turns on at once.
        XCTAssertTrue(plusBuildFlags(defaults).paidTier)
        defaults.removePersistentDomain(forName: suite)
    }

    /// 1.1.0 ships without Purchase History in its manifest (launch plan
    /// 4.5 adds it), so the default flags keep Plus off for this build.
    func test_thisBuildDeclaresNoPurchaseDataSoPlusStaysOff() {
        XCTAssertFalse(PrivacyDeclaration.bundleDeclaresPurchaseHistory())
        let flags = FeatureFlags(defaults: freshDefaults())
        flags.apply(FeaturesPayload(recipeFirst: true, paidTier: true))
        XCTAssertFalse(flags.paidTier)
    }

    func test_declaresPurchaseHistoryReadsTheManifestDataTypes() throws {
        func manifest(_ types: [String]) throws -> Data {
            let entries = types.map { ["NSPrivacyCollectedDataType": $0] }
            return try PropertyListSerialization.data(
                fromPropertyList: ["NSPrivacyCollectedDataTypes": entries], format: .xml, options: 0
            )
        }
        XCTAssertTrue(try PrivacyDeclaration.declaresPurchaseHistory(manifest: manifest([
            "NSPrivacyCollectedDataTypeEmailAddress", PrivacyDeclaration.purchaseHistoryType,
        ])))
        XCTAssertFalse(try PrivacyDeclaration.declaresPurchaseHistory(manifest: manifest([
            "NSPrivacyCollectedDataTypeEmailAddress",
        ])))
        XCTAssertFalse(PrivacyDeclaration.declaresPurchaseHistory(manifest: nil))
        XCTAssertFalse(PrivacyDeclaration.declaresPurchaseHistory(manifest: Data("not a plist".utf8)))
    }

    private func decode(_ json: String) throws -> DataResponse<FeaturesPayload> {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(DataResponse<FeaturesPayload>.self, from: Data(json.utf8))
    }
}
