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
        // 50MB memory / 200MB disk cache for images. Stays synchronous:
        // URLCache.shared is read by the first network call (validateToken
        // dispatched from AppState.init), so deferring this would race the
        // configured cache with the live request.
        URLCache.shared = URLCache(
            memoryCapacity: 50 * 1024 * 1024,
            diskCapacity: 200 * 1024 * 1024
        )

        // W131: everything below this line is cold-launch cleanup that
        // does not need to complete before the first interactive frame.
        // Hopping to a background Task moves the work off the main
        // thread so AppState.init + the WindowGroup body can render
        // without waiting on Keychain or MetricKit subscriber setup.
        Task.detached(priority: .background) {
            // W105: one-shot purge of the legacy email/password biometric
            // credential. Existing users had their password stored under
            // a biometric ACL; the new flow stores a refresh token
            // instead. Self-healing — once the legacy items are gone,
            // subsequent calls are no-ops.
            KeychainService.purgeLegacyBiometricCredential()

            // W119: subscribe to Apple's MetricKit so crash + performance
            // payloads flow into /admin/ios-crashes. Register exactly once
            // at launch — never inside a SwiftUI .onAppear, where a view
            // re-render would re-subscribe and double-post every payload.
            // Simulator builds register but never receive callbacks; only
            // physical devices deliver payloads. The internal `registered`
            // flag on MetricKitReporter still guards against double-
            // registration if this Task ever runs more than once.
            MetricKitReporter.shared.register()
        }
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
                // Universal Link tap. Routes by path prefix:
                //   /users/confirm/<token>  — email confirmation
                //   /p/<id>                 — shared post (D78)
                // Non-matching URLs are no-ops (Safari handles them).
                guard let url = userActivity.webpageURL else {
                    appLog.error("onContinueUserActivity fired but webpageURL was nil")
                    return
                }
                appLog.info("onContinueUserActivity received URL: host=\(url.host ?? "nil", privacy: .public) path=\(url.path, privacy: .public)")

                if appState.handlePostDeepLink(url: url) { return }
                Task { await appState.handleConfirmationDeepLink(url: url) }
            }
        }
    }
}
