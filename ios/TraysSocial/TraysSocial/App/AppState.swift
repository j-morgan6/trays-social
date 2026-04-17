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
            self.currentUser = user
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
}
