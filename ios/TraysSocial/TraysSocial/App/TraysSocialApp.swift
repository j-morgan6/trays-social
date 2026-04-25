import SwiftUI

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
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if appState.isAuthenticated {
                    if appState.isEmailVerified || appState.currentUser == nil {
                        MainView()
                    } else {
                        EmailVerificationGateView()
                    }
                } else {
                    WelcomeView()
                }
            }
            .environment(appState)
            .preferredColorScheme(preferredScheme)
        }
    }
}
