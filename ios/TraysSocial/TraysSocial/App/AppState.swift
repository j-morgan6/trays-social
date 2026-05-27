import os
import SwiftUI

private let deeplinkLog = Logger(subsystem: "com.trays.social", category: "deeplinks")

@MainActor
@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var selectedTray: TrayTab = .myTray
    var navigationPath = NavigationPath()
    /// Set when an API call returns a 403 with code "suspended". LoginView reads
    /// this on appear and surfaces it as an .alert, then calls
    /// clearSuspensionMessage(). Survives the logout state transition so the
    /// user actually sees why they were logged out.
    var suspensionMessage: String?

    /// Current toast message. `nil` when no error is visible. The
    /// `ErrorToast` view binds to this; rapid calls to `showError`
    /// coalesce — the latest message wins and the auto-dismiss timer
    /// restarts.
    var currentError: String?

    /// Cancellable handle for the auto-dismiss timer. Stored so a new
    /// `showError` call can cancel the previous countdown and start
    /// fresh from the most recent message.
    private var errorDismissTask: Task<Void, Never>?

    /// Observer token for the `.traysErrorOccurred` notification.
    /// Retained on AppState so ViewModels can post errors without
    /// holding an AppState reference.
    private var errorObserver: NSObjectProtocol?

    enum TrayTab: Int, CaseIterable {
        case feed = 0
        case myTray = 1
        case find = 2
    }

    var isValidatingToken = false

    var isEmailVerified: Bool {
        currentUser?.isEmailConfirmed ?? false
    }

    func refreshCurrentUser() async {
        guard isAuthenticated else { return }
        do {
            let user = try await AuthService.fetchMe()
            currentUser = user
        } catch {
            // Leave existing state untouched on transient errors
        }
    }

    init() {
        // Forward errors posted by ViewModels / Views (via
        // ErrorReporter.report) to the toast. Subscribing here keeps
        // callers free of any AppState dependency.
        errorObserver = NotificationCenter.default.addObserver(
            forName: .traysErrorOccurred,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            guard let message = notification.userInfo?["message"] as? String else { return }
            Task { @MainActor in
                self?.showError(message)
            }
        }

        // Check for existing token on launch
        if KeychainService.getToken() != nil {
            isAuthenticated = true
            validateToken()
        }
    }

    /// Surface a user-facing error message via the root-level toast.
    /// Coalesces: a second call replaces the first message and restarts
    /// the auto-dismiss countdown.
    func showError(_ message: String) {
        errorDismissTask?.cancel()
        currentError = message
        errorDismissTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                self?.currentError = nil
            }
        }
    }

    /// Hide the current toast immediately. Called when the user taps
    /// the banner or the dismiss button.
    func dismissCurrentError() {
        errorDismissTask?.cancel()
        currentError = nil
    }

    private func validateToken() {
        isValidatingToken = true
        Task {
            do {
                let user = try await AuthService.fetchMe()
                self.currentUser = user
                self.isValidatingToken = false
            } catch let APIError.suspended(message, until) {
                self.handleSuspended(message: message, until: until)
                self.isValidatingToken = false
            } catch {
                self.handleUnauthorized()
                self.isValidatingToken = false
            }
        }
    }

    func login(token: String, user: User) {
        KeychainService.save(token: token)
        // Reset before flipping isAuthenticated so AppShellView mounts with a
        // fresh stack and never reads a stale destination from a prior
        // session. (D32.)
        navigationPath = NavigationPath()
        currentUser = user
        isAuthenticated = true
    }

    func logout() {
        Task {
            try? await APIClient.shared.delete(path: "/auth/logout")
        }
        KeychainService.deleteToken()
        KeychainService.deleteBiometricCredential()
        currentUser = nil
        isAuthenticated = false
        // Drop pushed destinations from the previous session so the next
        // login starts on the root view. (D32.)
        navigationPath = NavigationPath()
    }

    func handleUnauthorized() {
        KeychainService.deleteToken()
        KeychainService.deleteBiometricCredential()
        currentUser = nil
        isAuthenticated = false
        navigationPath = NavigationPath()
    }

    /// Routes a suspended-response from any API call. Clears credentials like
    /// handleUnauthorized, but also stashes the message so LoginView can show
    /// it on appear (otherwise the user sees a silent logout with no
    /// explanation).
    func handleSuspended(message: String, until: Date?) {
        let formatted: String = {
            guard let until else { return message }
            let formatter = DateFormatter()
            formatter.dateStyle = .long
            return "\(message) Suspended until \(formatter.string(from: until))."
        }()

        suspensionMessage = formatted
        KeychainService.deleteToken()
        KeychainService.deleteBiometricCredential()
        currentUser = nil
        isAuthenticated = false
        navigationPath = NavigationPath()
    }

    func clearSuspensionMessage() {
        suspensionMessage = nil
    }

    /// Handles a Universal Link tap on a confirmation URL.
    ///
    /// Apple's WebKit hands us the `webpageURL` from a `NSUserActivity` when the
    /// user taps a `https://trays.app/users/confirm/<token>` link from an email
    /// (or anywhere else). We extract the token, POST it to the confirm API,
    /// and refresh the current user so `isEmailConfirmed` flips and the
    /// `EmailVerificationGateView` dismisses automatically.
    ///
    /// D62: we now always refresh /auth/me at the end, regardless of whether
    /// the confirm POST succeeded. This recovers the case where the token was
    /// already consumed (e.g., the user tapped the link in Safari before
    /// Universal Links registered post-D35, or iOS replays the activity on a
    /// scene re-activate). If the user's email is already confirmed in the DB,
    /// the refresh picks it up and the gate dismisses.
    ///
    /// Every failure branch logs to os.Logger so Console.app / sysdiagnose can
    /// surface the failure point. Tokens are never logged.
    func handleConfirmationDeepLink(url: URL) async {
        guard let token = confirmationToken(from: url) else {
            deeplinkLog.error(
                "confirm deep link rejected: not a /users/confirm/<token> URL (host=\(url.host ?? "nil", privacy: .public), path=\(url.path, privacy: .public))"
            )
            return
        }

        deeplinkLog.info("confirm deep link received: token length=\(token.count, privacy: .public)")

        do {
            let confirmed = try await AuthService.confirmEmail(token: token)
            if confirmed {
                deeplinkLog.info("confirm API returned confirmed=true; refreshing /auth/me")
            } else {
                deeplinkLog.error("confirm API returned confirmed=false; refreshing /auth/me anyway")
            }
        } catch {
            deeplinkLog.error(
                "confirm API call threw: \(String(describing: error), privacy: .public); refreshing /auth/me anyway in case the token was already consumed"
            )
        }

        // Always refresh — recovers the already-confirmed case and keeps the
        // gate's dismissal driven by the source of truth (the DB's
        // confirmed_at via GET /auth/me).
        await refreshCurrentUser()

        if currentUser?.isEmailConfirmed == true {
            deeplinkLog.info("post-refresh: isEmailConfirmed=true, gate should dismiss")
        } else {
            deeplinkLog.error("post-refresh: isEmailConfirmed=false, gate remains. User can use the 'I verified my email' button or 'Resend' to retry.")
        }
    }

    /// Extracts the confirmation token from a `/users/confirm/<token>` URL.
    /// Returns nil for any non-matching URL.
    private func confirmationToken(from url: URL) -> String? {
        let components = url.pathComponents
        // Expected: ["/", "users", "confirm", "<token>"]
        guard components.count == 4,
              components[1] == "users",
              components[2] == "confirm",
              !components[3].isEmpty
        else { return nil }
        return components[3]
    }
}
