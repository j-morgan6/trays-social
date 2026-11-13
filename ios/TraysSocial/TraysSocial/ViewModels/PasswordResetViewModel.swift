import Foundation
import OSLog

/// W256: the Reset your password screen's state. The user types an email,
/// the view model trims and checks it, asks the server to email a reset
/// link, and moves to the Check your email state. The server answers the
/// same way for every address, so nothing here ever says whether an account
/// exists. The typed email lives only in this screen-scoped model.
///
/// The send and the clock are injected so the tests can drive a failure, an
/// in-flight send and the 60-second resend cooldown without the network or
/// real time. The cooldown is a client-side convenience; the server's rate
/// limit is the authoritative one.
@MainActor
@Observable
final class PasswordResetViewModel {
    typealias Send = @MainActor (String) async throws -> Void

    enum State: Equatable {
        case form
        case sending
        case sent(email: String)
        case failed(message: String)
    }

    static let resendCooldown: TimeInterval = 60

    var email: String
    private(set) var state: State = .form
    /// The trimmed address of the last successful send. While it is set the
    /// screen shows the Check your email layout, so a resend that is in
    /// flight or failed keeps that layout.
    private(set) var sentEmail: String?
    private(set) var lastSentAt: Date?
    private(set) var emailNeedsAttention = false

    @ObservationIgnored private let send: Send
    @ObservationIgnored private let now: () -> Date

    private static let log = Logger(subsystem: "com.trays.social", category: "auth.password-reset")

    init(
        email: String = "",
        send: @escaping Send = PasswordResetViewModel.liveSend,
        now: @escaping () -> Date = Date.init
    ) {
        self.email = email
        self.send = send
        self.now = now
    }

    static func liveSend(_ email: String) async throws {
        try await AuthService.requestPasswordReset(email: email)
    }

    var isSending: Bool {
        state == .sending
    }

    var errorMessage: String? {
        if case let .failed(message) = state {
            return message
        }
        return nil
    }

    /// Whole seconds left before Resend link is available again, 0 when it is.
    var resendSecondsRemaining: Int {
        guard let lastSentAt else { return 0 }
        let remaining = Self.resendCooldown - now().timeIntervalSince(lastSentAt)
        return max(0, Int(remaining.rounded(.up)))
    }

    var canResend: Bool {
        sentEmail != nil && !isSending && resendSecondsRemaining == 0
    }

    /// The sent state's copy: names the address and the one-hour window, and
    /// stays neutral about whether an account uses it.
    var sentMessage: String? {
        guard let sentEmail else { return nil }
        // swiftlint:disable:next line_length
        return String(localized: "If an account uses \(sentEmail), a link to reset the password is on its way. The link works for one hour.")
    }

    /// What VoiceOver hears when the Check your email panel appears or a
    /// resend lands: the panel replaces the form without moving focus.
    var sentAnnouncement: String? {
        guard let sentMessage else { return nil }
        return String(localized: "Check your email") + ". " + sentMessage
    }

    /// Send reset link. Ignored while a send is in flight; a blank or
    /// malformed address shows the callout and sends nothing.
    func sendResetLink() async {
        guard !isSending else { return }
        let trimmed = email.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            showValidation(String(localized: "Enter your email address."))
            return
        }
        guard Self.isPlausibleEmail(trimmed) else {
            showValidation(String(localized: "Enter a valid email address."))
            return
        }
        await perform(trimmed)
    }

    /// Resend link, once the cooldown has run out.
    func resend() async {
        guard canResend, let sentEmail else { return }
        await perform(sentEmail)
    }

    /// Editing the field clears a shown callout.
    func emailChanged() {
        guard case .failed = state else { return }
        state = .form
        emailNeedsAttention = false
    }

    /// A light shape check only: something before and after one @, and a dot
    /// in the domain. The server judges the address too, and anything this
    /// lets through still gets the neutral sent state.
    static func isPlausibleEmail(_ value: String) -> Bool {
        value.wholeMatch(of: /[^\s@]+@[^\s@]+\.[^\s@]+/) != nil
    }

    // MARK: - Private

    private func showValidation(_ message: String) {
        state = .failed(message: message)
        emailNeedsAttention = true
    }

    private func perform(_ address: String) async {
        state = .sending
        emailNeedsAttention = false
        do {
            try await send(address)
            sentEmail = address
            lastSentAt = now()
            state = .sent(email: address)
            Self.log.info("password reset link requested")
        } catch {
            // The typed email, the last sent address and the cooldown stay as
            // they were, so a failure never starts a cooldown.
            state = .failed(message: Self.message(for: error))
            Self.log.error("password reset request failed: \(Self.logCategory(error), privacy: .public)")
        }
    }

    /// The callout for a failed send. Never mentions whether an account
    /// exists: the server does not say, and neither does the app.
    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited:
                return String(localized: "Too many requests. Try again in a few minutes.")
            case .validationError, .unprocessableEntity:
                return String(localized: "Enter a valid email address.")
            default:
                break
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return String(localized: "Couldn't send the link. Check your connection and try again.")
        }
        return String(localized: "Couldn't send the link. Try again in a moment.")
    }

    /// A category for the log line. Never the email or the server's text.
    private static func logCategory(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited: return "rateLimited"
            case .validationError, .unprocessableEntity: return "validation"
            case let .serverError(code): return "server(\(code))"
            default: return "api"
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "network(\(nsError.code))"
        }
        return "other"
    }
}
