import SwiftUI

@main
struct TraysSocialApp: App {
    @State private var appState = AppState()
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    private var preferredScheme: ColorScheme? {
        switch colorSchemePreference {
        case "light": return .light
        case "dark": return .dark
        default: return nil
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
                    MainView()
                } else {
                    WelcomeView()
                }
            }
            .environment(appState)
            .preferredColorScheme(preferredScheme)
        }
    }
}
