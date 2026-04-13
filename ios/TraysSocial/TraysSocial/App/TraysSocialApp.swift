import SwiftUI

@main
struct TraysSocialApp: App {
    @State private var appState = AppState()

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
            // Respects system light/dark mode setting
        }
    }
}
