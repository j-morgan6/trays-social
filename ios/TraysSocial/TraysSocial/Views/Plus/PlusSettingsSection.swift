import StoreKit
import SwiftUI

/// The permanent "Trays Plus" home in Settings — the always-available entry
/// point that makes the paywall reachable without ever nagging for it.
///
/// Lives in its own file rather than inline in `ProfileView.swift` for two
/// reasons: that file is already past swiftlint's `file_length` limit and
/// `SettingsView` is past `type_body_length`, and `.manageSubscriptionsSheet`
/// needs `import StoreKit`, which would drag StoreKit's `Transaction` into a
/// file that also uses SwiftUI's.
struct PlusSettingsSection: View {
    @Environment(AppState.self) private var appState

    @State private var showPaywall = false
    @State private var showManageSubscriptions = false

    var body: some View {
        Section(String(localized: "Trays Plus")) {
            if appState.isPlus {
                HStack {
                    Text(String(localized: "Status"))
                    Spacer()
                    // "Active" and nothing more: /auth/me carries only
                    // is_subscriber — no plan name, no renewal date. Inventing
                    // either would be a lie, and Apple's own sheet shows the
                    // real values one tap away.
                    Text(String(localized: "Active"))
                        .foregroundStyle(Theme.textSecondary)
                }
                .foregroundStyle(Theme.text)

                Button {
                    showManageSubscriptions = true
                } label: {
                    HStack {
                        Text(String(localized: "Manage subscription"))
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(Theme.text)
            } else {
                Button {
                    showPaywall = true
                } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(String(localized: "Get Trays Plus"))
                            Text(String(localized: "Ad-free, collections, planner, and grocery list"))
                                .font(.caption)
                                .foregroundStyle(Theme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
                .foregroundStyle(Theme.text)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(context: nil)
        }
        // iOS 15+, vended by StoreKit. In the Simulator this only renders
        // meaningfully when the StoreKit configuration is active (project.yml
        // binds TraysSocial.storekit to the Run action), so a build without it
        // presents nothing — expected, not a bug.
        .manageSubscriptionsSheet(isPresented: $showManageSubscriptions)
    }
}
