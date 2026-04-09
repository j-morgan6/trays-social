import SwiftUI

@Observable
final class AppState {
    var isAuthenticated = false
    var currentUser: User?
    var selectedTray: TrayTab = .feed

    enum TrayTab: Int, CaseIterable {
        case feed = 0
        case find = 1
        case myTray = 2
    }

    init() {
        // Check for existing token on launch
        if KeychainService.getToken() != nil {
            isAuthenticated = true
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
        currentUser = nil
        isAuthenticated = false
    }

    func handleUnauthorized() {
        KeychainService.deleteToken()
        currentUser = nil
        isAuthenticated = false
    }
}
