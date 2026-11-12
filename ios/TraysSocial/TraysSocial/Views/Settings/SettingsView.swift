import SwiftUI

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showCommunityGuidelines = false
    @State private var showAdminReports = false
    @State private var showAdminErrors = false
    @State private var showAdminDashboard = false
    @State private var showAdminIosCrashes = false
    @State private var showAdminFeedback = false
    @State private var showSendFeedback = false
    @AppStorage("colorScheme") private var colorSchemePreference = "system"
    // G37/W153: in-app language override, mirrors colorSchemePreference.
    // Values: system / en / fr / es. Applied app-wide in TraysSocialApp.
    @AppStorage("appLanguage") private var appLanguagePreference = "system"

    /// Fired when the user taps "Edit profile". The parent (ProfileView)
    /// is the natural owner of the EditProfileView sheet because it
    /// needs to re-fetch the profile on save (username changes are part
    /// of the route key). SettingsView dismisses itself before invoking
    /// the callback so the two sheet transitions don't compete.
    var onEditProfile: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    SettingsLinkRow(title: "Edit profile") {
                        dismiss()
                        onEditProfile?()
                    }

                    // Drafts: placeholder row, no destination yet. Kept
                    // discoverable so a future drafts list lands in the
                    // expected place without a layout shuffle.
                    HStack {
                        Text("Your drafts")
                            .foregroundStyle(Theme.text.opacity(0.5))
                        Spacer()
                        Text("Coming soon")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // W176. Body lives in Views/Plus/PlusSettingsSection.swift: the
                // section needs `import StoreKit` for the manage-subscriptions sheet.
                // W209: hidden while the server's paid_tier flag is off.
                if PlusVisibility.showsPlus(paidTier: FeatureFlags.shared.paidTier) {
                    PlusSettingsSection()
                }

                Section("Appearance") {
                    Picker("Mode", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                // G37/W153: language override, styled like Appearance above.
                // Language names show as endonyms (verbatim) so they read the
                // same regardless of the current locale. The footer states
                // that a restart finishes applying the change.
                Section {
                    Picker("Language", selection: $appLanguagePreference) {
                        Text("System").tag("system")
                        Text(verbatim: "English").tag("en")
                        Text(verbatim: "Français").tag("fr")
                        Text(verbatim: "Español").tag("es")
                    }
                    .pickerStyle(.segmented)
                    .onChange(of: appLanguagePreference) { _, newValue in
                        // Keep the bundle override in sync immediately so the
                        // choice persists and the next launch is fully aligned.
                        // "system" REMOVES the override (never write the device
                        // language) so the app keeps following device changes.
                        if newValue == "system" {
                            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
                        } else {
                            UserDefaults.standard.set([newValue], forKey: "AppleLanguages")
                        }
                    }
                } header: {
                    Text("Language")
                } footer: {
                    Text("Language changes finish applying after you restart Trays.")
                }

                Section("Content Filters") {
                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                    .foregroundStyle(Theme.text)

                    NavigationLink("Muted Keywords") {
                        MutedKeywordsView()
                    }
                    .foregroundStyle(Theme.text)
                }

                Section("Legal") {
                    SettingsLinkRow(title: "Privacy Policy") { showPrivacy = true }

                    SettingsLinkRow(title: "Terms of Service") { showTerms = true }

                    SettingsLinkRow(title: "Community Guidelines") { showCommunityGuidelines = true }
                }

                Section("Feedback") {
                    SettingsLinkRow(title: "Send Feedback") { showSendFeedback = true }
                }

                if appState.currentUser?.hasAdminAccess == true {
                    SettingsAdminSection(
                        showReports: $showAdminReports,
                        showErrors: $showAdminErrors,
                        showDashboard: $showAdminDashboard,
                        showIosCrashes: $showAdminIosCrashes,
                        showFeedback: $showAdminFeedback
                    )
                }

                Section {
                    Button("Log out") {
                        appState.logout()
                        dismiss()
                    }
                    .foregroundStyle(Theme.text)

                    Button("Delete account") {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        do {
                            // D104: only a confirmed 2xx means the account is
                            // gone — logging out on failure would leave the
                            // user believing data was deleted when it wasn't.
                            _ = try await APIClient.shared.delete(path: "/auth/me") as EmptyResponse
                            appState.handleUnauthorized()
                            dismiss()
                        } catch {
                            Toast.custom(String(localized: "Couldn't delete your account. Try again.")).show()
                        }
                    }
                }
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
            // Legal sheets — URL is built from the current build's API base
            // so a Debug install opens the review env's pages and a Release
            // install opens prod's, matching the admin-sheets pattern below.
            // The point: when iterating on Privacy / Terms / Community
            // Guidelines copy, a TestFlight reviewer on the Debug build can
            // verify the new wording on review.trays.app before it ships to
            // prod. Previously these three URLs were hardcoded to
            // https://trays.app/<path> while the admin sheets routed through
            // Configuration.apiBaseURL — the mixed strategy was the actual
            // D68 bug. See the ios_env_routing_gotchas memory; env routing
            // has bitten this project before (the build-15 Apple Sign In
            // double-encode incident is the cautionary tale).
            .sheet(isPresented: $showPrivacy) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/privacy")!)
            }
            .sheet(isPresented: $showCommunityGuidelines) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/community-guidelines")!)
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/terms")!)
            }
            // Admin sheets — URL is built from the current build's API base so
            // a Debug install opens the review env's admin pages and a Release
            // install opens prod's. Pre-authenticated session cookie is set on
            // the same hostname so the Safari sheet inherits the admin user's
            // browser session if one exists. Otherwise the user gets the
            // login screen (the admin pages are gated by RequireAdmin).
            .sheet(isPresented: $showAdminReports) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/reports")!)
            }
            .sheet(isPresented: $showAdminErrors) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/errors")!)
            }
            .sheet(isPresented: $showAdminDashboard) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/dashboard")!)
            }
            .sheet(isPresented: $showAdminIosCrashes) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/ios-crashes")!)
            }
            .sheet(isPresented: $showAdminFeedback) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/feedback")!)
            }
            .sheet(isPresented: $showSendFeedback) {
                FeedbackView()
            }
        }
    }
}

/// A Settings row that opens something: the title and a trailing chevron.
struct SettingsLinkRow: View {
    let title: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(title)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
        }
        .foregroundStyle(Theme.text)
    }
}

/// The admin-only rows. The sheets stay on SettingsView, so this only flips
/// the bindings it is handed.
struct SettingsAdminSection: View {
    @Binding var showReports: Bool
    @Binding var showErrors: Bool
    @Binding var showDashboard: Bool
    @Binding var showIosCrashes: Bool
    @Binding var showFeedback: Bool

    var body: some View {
        Section("Admin") {
            SettingsLinkRow(title: "Reports") { showReports = true }
            SettingsLinkRow(title: "Error Tracker") { showErrors = true }
            SettingsLinkRow(title: "System Dashboard") { showDashboard = true }
            SettingsLinkRow(title: "iOS Crashes") { showIosCrashes = true }
            SettingsLinkRow(title: "Feedback") { showFeedback = true }
        }
    }
}
