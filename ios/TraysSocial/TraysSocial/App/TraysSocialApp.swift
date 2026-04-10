import SwiftUI

@main
struct TraysSocialApp: App {
    @State private var appState = AppState()

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
