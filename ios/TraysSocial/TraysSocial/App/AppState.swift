import SwiftUI

@MainActor
@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var selectedTray: TrayTab = .feed
    var navigationPath = NavigationPath()

    enum TrayTab: Int, CaseIterable {
        case feed = 0
        case find = 1
        case myTray = 2
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
        // Check for existing token on launch
        if KeychainService.getToken() != nil {
            isAuthenticated = true
            validateToken()
        }
    }

    private func validateToken() {
        isValidatingToken = true
        Task {
            do {
                let user = try await AuthService.fetchMe()
                self.currentUser = user
                self.isValidatingToken = false
            } catch {
                self.handleUnauthorized()
                self.isValidatingToken = false
            }
        }
    }

    func login(token: String, user: User) {
        KeychainService.save(token: token)
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
    }

    func handleUnauthorized() {
        KeychainService.deleteToken()
        KeychainService.deleteBiometricCredential()
        currentUser = nil
        isAuthenticated = false
    }

    /// Handles a Universal Link tap on a confirmation URL.
    ///
    /// Apple's WebKit hands us the `webpageURL` from a `NSUserActivity` when the
    /// user taps a `https://trays.app/users/confirm/<token>` link from an email
    /// (or anywhere else). We extract the token, POST it to the confirm API,
    /// and refresh the current user so `isEmailConfirmed` flips and the
    /// `EmailVerificationGateView` dismisses automatically.
    ///
    /// Failure is silent: the user can still tap "I verified my email" on the
    /// gate to retry via `refreshCurrentUser()`. We don't want to surface a
    /// generic error toast for a bad token because the gate already provides a
    /// retry path.
    func handleConfirmationDeepLink(url: URL) async {
        guard let token = confirmationToken(from: url) else { return }

        do {
            let confirmed = try await AuthService.confirmEmail(token: token)
            if confirmed {
                await refreshCurrentUser()
            }
        } catch {
            // Silent — gate retry path remains available.
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
