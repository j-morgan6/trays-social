import os
import SwiftUI

private let appLog = Logger(subsystem: "com.trays.social", category: "deeplinks")

@main
struct TraysSocialApp: App {
    @State private var appState = AppState()
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }

    init() {
        // 50MB memory / 200MB disk cache for images
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        // W105: one-shot purge of the legacy email/password biometric
        // credential. Existing users had their password stored under a
        // biometric ACL; the new flow stores a refresh token instead.
        // Purging on every launch is cheap (it's a Keychain delete) and
        // self-healing — once gone, subsequent calls are no-ops. Users
        // log in once with their password to re-opt into biometric, at
        // which point the refresh-token path takes over.
        KeychainService.purgeLegacyBiometricCredential()
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    if appState.isEmailVerified || appState.currentUser == nil {
                        AppShellView()
                    } else {
                        EmailVerificationGateView()
                    }
                } else {
                    WelcomeView()
                }
            }
            .environment(appState)
            .overlay(alignment: .top) {
                // W113: app-root toast for surfaced errors. Sits above
                // every screen; flows that present a sheet should keep
                // their existing inline error UI (the root overlay does
                // not layer above modal sheets).
                ErrorToast()
                    .environment(appState)
            }
            .preferredColorScheme(preferredScheme)
            .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { userActivity in
                // Universal Link tap. Currently we only intercept
                // /users/confirm/<token>; AppState filters non-matching URLs.
                guard let url = userActivity.webpageURL else {
                    appLog.error("onContinueUserActivity fired but webpageURL was nil")
                    return
                }
                appLog.info("onContinueUserActivity received URL: host=\(url.host ?? "nil", privacy: .public) path=\(url.path, privacy: .public)")
                Task { await appState.handleConfirmationDeepLink(url: url) }
            }
        }
    }
}
