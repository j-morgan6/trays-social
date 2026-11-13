import Foundation
@testable import TraysSocial
import UIKit
import XCTest

/// W263: the feedback sheet's form. A report carries its kind, the app
/// build and the screen it was opened from on top of the W125 keys; the
/// body is 1 to 5,000 characters after trimming and the subject at most
/// 200; a failed or rate-limited send shows an inline message and keeps
/// everything typed; a second submit while one is in flight is ignored.
@MainActor
final class FeedbackFormTests: XCTestCase {
    private var sender: FeedbackSenderSpy!

    private let device = FeedbackDeviceInfo(
        appVersion: "1.1.0",
        appBuild: "414",
        osVersion: "26.1.0",
        deviceModel: "iPhone18,1"
    )

    override func setUp() async throws {
        try await super.setUp()
        sender = FeedbackSenderSpy()
    }

    override func tearDown() async throws {
        sender = nil
        try await super.tearDown()
    }

    private func makeForm(entryPoint: FeedbackEntryPoint = .settings, kind: FeedbackKind? = nil) -> FeedbackForm {
        let sender = sender!
        return FeedbackForm(
            entryPoint: entryPoint,
            kind: kind,
            device: device,
            send: { try await sender.send($0) }
        )
    }

    private func encodedObject(_ request: FeedbackRequest) throws -> [String: Any] {
        let data = try JSONEncoder.apiEncoder.encode(request)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }

    func test_aBugReportEncodesKindBuildAndScreen() async throws {
        let form = makeForm(entryPoint: .verifyEmail)
        form.kind = .bug
        form.subject = " Verify link "
        form.body = "  The link in the email does nothing \n"

        let request = try XCTUnwrap(form.makeRequest())
        let object = try encodedObject(request)

        XCTAssertEqual(
            Set(object.keys),
            ["kind", "subject", "body", "app_version", "app_build", "os_version", "device_model", "screen"]
        )
        XCTAssertEqual(object["kind"] as? String, "bug")
        XCTAssertEqual(object["app_build"] as? String, "414")
        XCTAssertEqual(object["screen"] as? String, "verify_email")
        XCTAssertEqual(object["app_version"] as? String, "1.1.0")
        XCTAssertEqual(object["os_version"] as? String, "26.1.0")
        XCTAssertEqual(object["device_model"] as? String, "iPhone18,1")
        XCTAssertEqual(object["subject"] as? String, "Verify link")
        XCTAssertEqual(object["body"] as? String, "The link in the email does nothing")
        XCTAssertNil(object["platform"], "the server sets platform; the app never sends it")

        await form.submit()
        XCTAssertEqual(sender.requests, [request])
        XCTAssertEqual(form.state, .sent)

        // The live build number is CFBundleVersion.
        XCTAssertEqual(
            FeedbackDeviceInfo.current.appBuild,
            Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
        XCTAssertNotNil(FeedbackDeviceInfo.current.appBuild)
    }

    func test_theBodyIs5000CharactersAtMost() async {
        XCTAssertEqual(FeedbackForm.bodyLimit, 5000)
        XCTAssertEqual(FeedbackForm.subjectLimit, 200)

        let form = makeForm()
        form.body = String(repeating: "a", count: 5000)
        XCTAssertTrue(form.canSubmit)
        XCTAssertFalse(form.bodyIsOverLimit)
        XCTAssertEqual(form.bodyCount, 5000)

        form.body = String(repeating: "a", count: 5001)
        XCTAssertFalse(form.canSubmit)
        XCTAssertTrue(form.bodyIsOverLimit)
        XCTAssertNil(form.makeRequest())
        await form.submit()
        XCTAssertTrue(sender.requests.isEmpty, "an over-long body never reaches the network")

        // Surrounding whitespace does not count, as on the server.
        form.body = String(repeating: "a", count: 5000) + "  \n"
        XCTAssertTrue(form.canSubmit)

        // Characters, not code points: an accented letter built from two
        // scalars counts once, matching the server's String.length.
        form.body = String(repeating: "e\u{301}", count: 5000)
        XCTAssertTrue(form.canSubmit)

        form.body = String(repeating: "a", count: 5000)
        await form.submit()
        XCTAssertEqual(sender.requests.first?.body.count, 5000)
    }

    func test_aRateLimitedReplyShowsTheTryLaterMessageAndKeepsTheText() async {
        let mapped = await APIClient.shared.mapError(
            statusCode: 429,
            data: Data(#"{"errors":[{"message":"too many requests"}]}"#.utf8)
        )
        sender.error = mapped
        let form = makeForm(kind: .bug)
        form.subject = "Crash "
        form.body = "It closes when I open a recipe "

        await form.submit()

        XCTAssertEqual(form.state, .failed(message: "Too many reports in the last hour. Try again later."))
        XCTAssertEqual(form.errorMessage, "Too many reports in the last hour. Try again later.")
        XCTAssertEqual(form.subject, "Crash ", "the typed subject is kept as typed")
        XCTAssertEqual(form.body, "It closes when I open a recipe ", "the typed body is kept as typed")
        XCTAssertEqual(form.kind, .bug)
        XCTAssertTrue(form.canSubmit, "the user can retry")

        sender.error = nil
        await form.submit()
        XCTAssertEqual(form.state, .sent)
        XCTAssertEqual(sender.requests.count, 2)
    }

    func test_canSubmitNeedsANonBlankBodyWithinTheLimits() async {
        let form = makeForm()
        for blank in ["", "   ", "\n\t"] {
            form.body = blank
            XCTAssertFalse(form.canSubmit, "for \(blank.debugDescription)")
            XCTAssertNil(form.makeRequest(), "for \(blank.debugDescription)")
        }
        await form.submit()
        XCTAssertTrue(sender.requests.isEmpty, "a blank body is never sent")

        form.body = "x"
        XCTAssertTrue(form.canSubmit)
        XCTAssertNil(form.makeRequest()?.subject, "a blank subject is left out")

        form.subject = String(repeating: "s", count: 200)
        XCTAssertTrue(form.canSubmit)
        form.subject = String(repeating: "s", count: 201)
        XCTAssertFalse(form.canSubmit)
        XCTAssertTrue(form.subjectIsOverLimit)
    }

    func test_aSecondSubmitWhileSendingIsIgnored() async {
        sender.holds = true
        let form = makeForm()
        form.body = "The timer stops when the screen locks"

        let first = Task { await form.submit() }
        var spins = 0
        while sender.pending.isEmpty, spins < 1000 {
            await Task.yield()
            spins += 1
        }
        XCTAssertEqual(sender.pending.count, 1, "the first submit is in flight")
        XCTAssertEqual(form.state, .sending)
        XCTAssertFalse(form.canSubmit)

        // A second tap as its own task, so a regression that let it through
        // is caught by the count rather than hanging the test.
        let second = Task { await form.submit() }
        for _ in 0 ..< 100 {
            await Task.yield()
        }
        XCTAssertEqual(sender.requests.count, 1, "a second submit while sending is ignored")

        sender.release()
        await first.value
        await second.value
        XCTAssertEqual(form.state, .sent)
        XCTAssertEqual(sender.requests.count, 1)

        await form.submit()
        XCTAssertEqual(sender.requests.count, 1, "nothing is sent again once a report went through")
    }

    func test_theEntryPointBecomesTheScreenValue() {
        XCTAssertEqual(FeedbackEntryPoint.settings.screen, "settings")
        XCTAssertEqual(FeedbackEntryPoint.verifyEmail.screen, "verify_email")

        for entryPoint in [FeedbackEntryPoint.settings, .verifyEmail] {
            let form = makeForm(entryPoint: entryPoint)
            form.body = "Hello"
            XCTAssertEqual(form.makeRequest()?.screen, entryPoint.screen)
        }

        XCTAssertEqual(makeForm(entryPoint: .settings).kind, .feedback)
        XCTAssertEqual(makeForm(entryPoint: .verifyEmail).kind, .bug)

        XCTAssertEqual(SettingsView.feedbackEntryPoint, .settings)
        XCTAssertEqual(EmailVerificationGateView.feedbackEntryPoint, .verifyEmail)
    }

    /// Change the Rights: the session expires while the sheet is open. There
    /// is no global 401 handler; the sheet shows the existing session-expired
    /// copy inline and keeps everything typed.
    func test_aSessionExpiredReplyShowsTheExistingMessageAndKeepsTheText() async {
        sender.error = await APIClient.shared.mapError(statusCode: 401, data: Data())
        let form = makeForm(kind: .bug)
        form.subject = "Gate"
        form.body = "The verify button spins forever"

        await form.submit()

        XCTAssertEqual(form.errorMessage, "Session expired. Please log in again.")
        XCTAssertEqual(form.subject, "Gate")
        XCTAssertEqual(form.body, "The verify button spins forever")
        XCTAssertEqual(form.kind, .bug)
        XCTAssertTrue(form.canSubmit)
    }

    /// The server counts the subject in code points (a varchar column), so a
    /// subject of combining-mark letters is limited by its code points.
    func test_theSubjectLimitCountsCodePointsLikeTheServer() {
        let form = makeForm()
        form.body = "Hello"
        form.subject = String(repeating: "e\u{301}", count: 100)
        XCTAssertEqual(form.subject.count, 100)
        XCTAssertTrue(form.canSubmit, "100 characters, 200 code points")

        form.subject = String(repeating: "e\u{301}", count: 101)
        XCTAssertFalse(form.canSubmit, "101 characters, 202 code points")
        XCTAssertTrue(form.subjectIsOverLimit)
    }

    func test_aNetworkFailureKeepsSubjectAndBody() async throws {
        sender.error = URLError(.notConnectedToInternet)
        let form = makeForm()
        form.subject = "Idea"
        form.body = "A shopping list from a recipe would help"

        await form.submit()

        XCTAssertEqual(
            form.errorMessage,
            "Couldn't send your feedback. Check your connection and try again."
        )
        XCTAssertEqual(form.subject, "Idea")
        XCTAssertEqual(form.body, "A shopping list from a recipe would help")
        XCTAssertEqual(form.kind, .feedback)

        // Editing clears the message but never the text.
        form.clearError()
        XCTAssertEqual(form.state, .editing)

        sender.error = nil
        await form.submit()
        XCTAssertEqual(form.state, .sent)
        XCTAssertEqual(sender.requests.count, 2)
        XCTAssertEqual(sender.requests[0], sender.requests[1], "the retry sends the same report")

        let object = try encodedObject(sender.requests[1])
        XCTAssertEqual(object["subject"] as? String, "Idea")
        XCTAssertEqual(object["body"] as? String, "A shopping list from a recipe would help")
    }

    /// Every Locale: each new W263 string is in the catalog with a Spanish
    /// and a French translation, read back from the built bundle.
    func test_newStringsAreTranslatedIntoSpanishAndFrench() throws {
        let keys = [
            "Report a bug or send feedback",
            "Report a problem",
            "Report a bug",
            "Send feedback",
            "Bug",
            "Send",
            "Subject",
            "What happened?",
            "What's on your mind?",
            "We include your app version, build, iOS version and device model with your message.",
            "Keep the subject to 200 characters.",
            "Keep it to 5,000 characters.",
            "Too many reports in the last hour. Try again later.",
            "Couldn't send your feedback. Check your connection and try again.",
            "Trouble signing in?",
            "Copy email address",
        ]
        for locale in ["es", "fr"] {
            let path = try XCTUnwrap(Bundle.main.path(forResource: locale, ofType: "lproj"), "no \(locale).lproj")
            let bundle = try XCTUnwrap(Bundle(path: path))
            for key in keys {
                let missing = "__missing__"
                let value = bundle.localizedString(forKey: key, value: missing, table: "Localizable")
                XCTAssertNotEqual(value, missing, "\(locale) has no entry for \(key.debugDescription)")
                XCTAssertNotEqual(value, key, "\(locale) leaves \(key.debugDescription) untranslated")
            }
        }
    }

    func test_troubleSigningInMailsThePublishedSupportAddress() {
        XCTAssertEqual(LoginSupportLine.supportEmail, "support@trays.app")
        XCTAssertEqual(LoginSupportLine.mailURL.absoluteString, "mailto:support@trays.app")
    }

    /// No mail app installed: Copy email address puts the address on the
    /// pasteboard (a Link label cannot take text selection).
    func test_copyEmailAddressPutsTheSupportAddressOnThePasteboard() throws {
        let pasteboard = try XCTUnwrap(UIPasteboard(name: UIPasteboard.Name("W263-support-line"), create: true))
        defer { UIPasteboard.remove(withName: pasteboard.name) }
        pasteboard.string = ""

        LoginSupportLine.copyAddress(to: pasteboard)

        XCTAssertEqual(pasteboard.string, "support@trays.app")
    }
}

/// Records each request, can throw, and can hold a send open until released.
@MainActor
final class FeedbackSenderSpy {
    var requests: [FeedbackRequest] = []
    var error: Error?
    var holds = false
    /// Every held send, so a release never strands one even if a second
    /// send slipped through.
    private(set) var pending: [CheckedContinuation<Void, Never>] = []

    func send(_ request: FeedbackRequest) async throws {
        requests.append(request)
        if holds {
            await withCheckedContinuation { pending.append($0) }
        }
        if let error {
            throw error
        }
    }

    func release() {
        let held = pending
        pending = []
        held.forEach { $0.resume() }
    }
}
