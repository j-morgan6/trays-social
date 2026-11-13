import Foundation
@testable import TraysSocial
import XCTest

/// W256: Reset your password. A valid address is trimmed and sent once,
/// a blank or malformed one never reaches the network, a failure keeps the
/// typed email, Resend link waits 60 seconds after each send, and the sent
/// copy names the address and the one-hour window without saying whether
/// an account exists.
@MainActor
final class PasswordResetViewModelTests: XCTestCase {
    private var sender: ResetSenderSpy!
    private var clock: ResetTestClock!

    override func setUp() async throws {
        try await super.setUp()
        sender = ResetSenderSpy()
        clock = ResetTestClock(now: Date(timeIntervalSince1970: 1_800_000_000))
    }

    override func tearDown() async throws {
        sender = nil
        clock = nil
        try await super.tearDown()
    }

    private func makeViewModel(email: String = "") -> PasswordResetViewModel {
        let sender = sender!
        let clock = clock!
        return PasswordResetViewModel(
            email: email,
            send: { try await sender.send($0) },
            now: { clock.now }
        )
    }

    func test_sendingAValidEmailMovesToSentWithTheTrimmedEmail() async {
        let vm = makeViewModel(email: "  cook@example.com \n")

        await vm.sendResetLink()

        XCTAssertEqual(sender.calls, ["cook@example.com"])
        XCTAssertEqual(vm.state, .sent(email: "cook@example.com"))
        XCTAssertEqual(vm.sentEmail, "cook@example.com")
        XCTAssertNil(vm.errorMessage)
    }

    func test_aBlankOrMalformedEmailStaysOnTheFormWithACallout() async {
        let blank = ["", "   ", "\n\t"]
        let malformed = ["cook", "cook@", "@example.com", "cook@example", "co ok@example.com", "a@b@example.com"]

        for value in blank + malformed {
            let vm = makeViewModel(email: value)
            await vm.sendResetLink()

            let expected = blank.contains(value) ? "Enter your email address." : "Enter a valid email address."
            XCTAssertEqual(vm.state, .failed(message: expected), "for \(value.debugDescription)")
            XCTAssertNil(vm.sentEmail, "for \(value.debugDescription)")
            XCTAssertTrue(vm.emailNeedsAttention, "for \(value.debugDescription)")
            XCTAssertEqual(vm.email, value, "the typed value is kept")
        }
        XCTAssertEqual(sender.calls, [], "no request for a blank or malformed email")
    }

    func test_aNetworkFailureShowsTheCalloutAndKeepsTheEmail() async {
        sender.error = URLError(.notConnectedToInternet)
        let vm = makeViewModel(email: "cook@example.com")

        await vm.sendResetLink()

        XCTAssertEqual(
            vm.state,
            .failed(message: "Couldn't send the link. Check your connection and try again.")
        )
        XCTAssertEqual(vm.email, "cook@example.com")
        XCTAssertNil(vm.sentEmail)
        XCTAssertNil(vm.lastSentAt, "a failure starts no cooldown")

        sender.error = nil
        await vm.sendResetLink()
        XCTAssertEqual(vm.state, .sent(email: "cook@example.com"))
        XCTAssertEqual(sender.calls.count, 2)
    }

    func test_resendIsDisabledForSixtySecondsAfterASend() async {
        let vm = makeViewModel(email: "cook@example.com")
        await vm.sendResetLink()

        XCTAssertFalse(vm.canResend)
        XCTAssertEqual(vm.resendSecondsRemaining, 60)

        clock.advance(by: 59)
        XCTAssertFalse(vm.canResend)
        XCTAssertEqual(vm.resendSecondsRemaining, 1)
        await vm.resend()
        XCTAssertEqual(sender.calls.count, 1, "resend is ignored during the cooldown")

        clock.advance(by: 1)
        XCTAssertTrue(vm.canResend)
        XCTAssertEqual(vm.resendSecondsRemaining, 0)
        await vm.resend()
        XCTAssertEqual(sender.calls, ["cook@example.com", "cook@example.com"])

        XCTAssertFalse(vm.canResend, "every send restarts the cooldown")
        XCTAssertEqual(vm.resendSecondsRemaining, 60)
    }

    func test_aSecondSendWhileSendingIsIgnored() async {
        sender.holds = true
        let vm = makeViewModel(email: "cook@example.com")

        let first = Task { await vm.sendResetLink() }
        var spins = 0
        while sender.pending.isEmpty, spins < 1000 {
            await Task.yield()
            spins += 1
        }
        XCTAssertEqual(sender.pending.count, 1, "the first send is in flight")
        XCTAssertEqual(vm.state, .sending)

        // Run the second tap as its own task so a regression that let it
        // through would be caught by the count rather than hang the test.
        let second = Task { await vm.sendResetLink() }
        for _ in 0 ..< 100 {
            await Task.yield()
        }
        XCTAssertEqual(sender.calls.count, 1, "a second send while sending is ignored")

        sender.release()
        await first.value
        await second.value
        XCTAssertEqual(vm.state, .sent(email: "cook@example.com"))
        XCTAssertEqual(sender.calls.count, 1)
    }

    func test_sentCopyNamesTheEmailAndTheOneHourWindow() async throws {
        let vm = makeViewModel(email: "cook@example.com")
        XCTAssertNil(vm.sentMessage)

        await vm.sendResetLink()

        let message = try XCTUnwrap(vm.sentMessage)
        XCTAssertEqual(
            message,
            "If an account uses cook@example.com, a link to reset the password is on its way. "
                + "The link works for one hour."
        )
        let lowered = message.lowercased()
        XCTAssertFalse(lowered.contains("no account"))
        XCTAssertFalse(lowered.contains("not found"))
    }

    func test_sentAnnouncementNamesTheStateAndTheEmail() async throws {
        let vm = makeViewModel(email: "cook@example.com")
        XCTAssertNil(vm.sentAnnouncement, "nothing to announce before a send")

        await vm.sendResetLink()

        let announcement = try XCTUnwrap(vm.sentAnnouncement)
        XCTAssertTrue(announcement.hasPrefix("Check your email. "))
        XCTAssertTrue(announcement.contains("cook@example.com"))
        XCTAssertTrue(announcement.contains("one hour"))
    }

    /// Every Locale: each new W256 string is in the catalog with a Spanish
    /// and a French translation, read back from the built bundle.
    func test_newStringsAreTranslatedIntoSpanishAndFrench() throws {
        let keys = [
            "Forgot password?",
            "Reset your password",
            "Enter the email you use for Trays and we\u{2019}ll send you a link to set a new password.",
            "Send reset link",
            "Sending reset link",
            "If an account uses %@, a link to reset the password is on its way. The link works for one hour.",
            "Open Mail",
            "Resend link",
            "Remembered it?",
            "Back to log in",
            "Enter your email address.",
            "Enter a valid email address.",
            "Couldn't send the link. Check your connection and try again.",
            "Couldn't send the link. Try again in a moment.",
            "Too many requests. Try again in a few minutes.",
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

    func test_requestBodyEncodesOnlyTheEmailKey() throws {
        let data = try JSONEncoder.apiEncoder.encode(AuthService.PasswordResetRequest(email: "cook@example.com"))
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])

        XCTAssertEqual(Array(object.keys), ["email"])
        XCTAssertEqual(object["email"] as? String, "cook@example.com")
    }
}

/// Records each send, can throw, and can hold a send open until released.
@MainActor
final class ResetSenderSpy {
    var calls: [String] = []
    var error: Error?
    var holds = false
    /// Every held send, so a release never strands one even if a second
    /// send slipped through.
    private(set) var pending: [CheckedContinuation<Void, Never>] = []

    func send(_ email: String) async throws {
        calls.append(email)
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

final class ResetTestClock: @unchecked Sendable {
    var now: Date

    init(now: Date) {
        self.now = now
    }

    func advance(by seconds: TimeInterval) {
        now = now.addingTimeInterval(seconds)
    }
}
