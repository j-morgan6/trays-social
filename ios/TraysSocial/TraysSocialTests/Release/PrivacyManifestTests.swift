import XCTest

/// W213: pins the app's privacy manifest (PrivacyInfo.xcprivacy) as it is
/// bundled into the built app. The test bundle is hosted by TraysSocial.app,
/// so `Bundle.main` is the app bundle, not the test bundle.
///
/// `expectedCollectedTypes` is a hand-kept copy of the "Data declared" table in
/// docs/app-store-privacy-checklist.md; nothing parses that file. When the
/// checklist changes, update this list, the manifest and App Store Connect's
/// App Privacy answers together.
@MainActor
final class PrivacyManifestTests: XCTestCase {
    private static let expectedCollectedTypes: Set<String> = [
        "NSPrivacyCollectedDataTypeEmailAddress",
        "NSPrivacyCollectedDataTypeName",
        "NSPrivacyCollectedDataTypePhotosorVideos",
        "NSPrivacyCollectedDataTypeOtherUserContent",
        "NSPrivacyCollectedDataTypeCustomerSupport",
        "NSPrivacyCollectedDataTypeUserID",
        "NSPrivacyCollectedDataTypeDeviceID",
        "NSPrivacyCollectedDataTypeProductInteraction",
        "NSPrivacyCollectedDataTypeCrashData",
        "NSPrivacyCollectedDataTypePerformanceData",
    ]

    private func manifest() throws -> [String: Any] {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"),
            "PrivacyInfo.xcprivacy is not in the app bundle's resources"
        )
        let data = try Data(contentsOf: url)
        let plist = try PropertyListSerialization.propertyList(from: data, format: nil)
        return try XCTUnwrap(plist as? [String: Any], "manifest root is not a dictionary")
    }

    private func collectedTypes() throws -> [[String: Any]] {
        try XCTUnwrap(try manifest()["NSPrivacyCollectedDataTypes"] as? [[String: Any]])
    }

    func test_bundleContainsPrivacyManifest() {
        XCTAssertNotNil(Bundle.main.url(forResource: "PrivacyInfo", withExtension: "xcprivacy"))
    }

    func test_manifestDeclaresUserDefaultsReasonCA92_1() throws {
        let apis = try XCTUnwrap(try manifest()["NSPrivacyAccessedAPITypes"] as? [[String: Any]])
        let userDefaults = apis.filter {
            $0["NSPrivacyAccessedAPIType"] as? String == "NSPrivacyAccessedAPICategoryUserDefaults"
        }
        XCTAssertEqual(userDefaults.count, 1)
        XCTAssertEqual(userDefaults.first?["NSPrivacyAccessedAPITypeReasons"] as? [String], ["CA92.1"])
        // No other required-reason API is used (2026-10-28 scan); declaring one
        // the app doesn't use is a false declaration.
        XCTAssertEqual(apis.count, 1)
    }

    func test_manifestDeclaresNoTracking() throws {
        let manifest = try manifest()
        XCTAssertEqual(manifest["NSPrivacyTracking"] as? Bool, false)
        XCTAssertEqual((manifest["NSPrivacyTrackingDomains"] as? [String])?.count, 0)
        for entry in try collectedTypes() {
            XCTAssertEqual(
                entry["NSPrivacyCollectedDataTypeTracking"] as? Bool, false,
                "\(entry["NSPrivacyCollectedDataType"] ?? "?") is marked as tracking"
            )
        }
    }

    func test_manifestDeclaresExpectedCollectedDataTypes() throws {
        let types = try collectedTypes().compactMap { $0["NSPrivacyCollectedDataType"] as? String }
        XCTAssertEqual(types.count, Self.expectedCollectedTypes.count, "duplicate or missing entries")
        XCTAssertEqual(Set(types), Self.expectedCollectedTypes)
        // Purchase history arrives with the Plus release, not 1.1.0. While it
        // is absent, FeatureFlags keeps paid_tier off in this build, so the
        // dormant StoreKit code cannot send undeclared purchase data.
        XCTAssertFalse(types.contains("NSPrivacyCollectedDataTypePurchaseHistory"))
    }

    /// Every type is linked to the user, per the checklist: the MetricKit
    /// crash and performance payloads are stored with the signed-in user's ID.
    /// App Functionality is the only purpose; anything else (analytics,
    /// advertising) would need a checklist and App Store Connect change first.
    func test_everyCollectedTypeIsLinkedForAppFunctionalityOnly() throws {
        for entry in try collectedTypes() {
            let name = entry["NSPrivacyCollectedDataType"] as? String ?? "?"
            XCTAssertEqual(entry["NSPrivacyCollectedDataTypeLinked"] as? Bool, true, "\(name) linked flag")
            XCTAssertEqual(
                entry["NSPrivacyCollectedDataTypePurposes"] as? [String],
                ["NSPrivacyCollectedDataTypePurposeAppFunctionality"],
                "\(name) purposes"
            )
        }
    }
}
