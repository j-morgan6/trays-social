import XCTest

/// W213: pins the release-facing Info.plist values of the built app.
@MainActor
final class InfoPlistTests: XCTestCase {
    /// The last build number uploaded before 1.1.0 (pbxproj on 2026-10-23).
    /// scripts/regen-xcodeproj.sh derives the build number from the commit
    /// count, so a bare `xcodegen generate` that resets it to project.yml's
    /// stale value fails this test.
    private static let lastUploadedBuild = 372

    private func info(_ key: String) -> Any? {
        Bundle.main.object(forInfoDictionaryKey: key)
    }

    func test_declaresNoNonExemptEncryption() {
        XCTAssertEqual(info("ITSAppUsesNonExemptEncryption") as? Bool, false)
    }

    func test_marketingVersionIs1_1_0() {
        XCTAssertEqual(info("CFBundleShortVersionString") as? String, "1.1.0")
    }

    func test_buildNumberDidNotRegress() throws {
        let raw = try XCTUnwrap(info("CFBundleVersion") as? String)
        let build = try XCTUnwrap(Int(raw), "CFBundleVersion \(raw) is not an integer")
        XCTAssertGreaterThanOrEqual(build, Self.lastUploadedBuild)
    }
}
