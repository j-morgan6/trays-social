import SwiftUI

/// The verify-email gate shown to a signed-in user whose email is not yet
/// confirmed. W251: restyled to the Login artboard's "Check your email"
/// state (emerald band, rounded heading, mint panel, amber button). The
/// refresh, resend cooldown and sign-out behaviour are unchanged.
struct EmailVerificationGateView: View {
    @Environment(AppState.self) private var appState
    @State private var isResending = false
    @State private var isRefreshing = false
    @State private var statusMessage: String?
    @State private var lastResendAt: Date?

    private let resendCooldown: TimeInterval = 60

    var body: some View {
        AuthScreen(band: .standard) {
            AuthHeading(title: "Verify your email")

            // The mint "Check your email" panel from the Login artboard.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope")
                    .scaledFont(18, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Theme.text)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Check your email")
                        .roundedFont(17, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Theme.text)

                    Text("We sent a verification link to")
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(appState.currentUser?.email ?? String(localized: "your email"))
                        .fontWeight(.semibold)
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                        .truncationMode(.middle)

                    Text("Tap the link in that email, then return here.")
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.top, 4)
                }
                .scaledFont(14.5, relativeTo: .subheadline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.mintTint))
            .accessibilityElement(children: .combine)
            .padding(.top, 24)

            if let message = statusMessage {
                AuthCallout(message: message, systemImage: "info.circle")
                    .padding(.top, 16)
            }

            Spacer(minLength: 24)

            VStack(spacing: 12) {
                Button {
                    Task { await refresh() }
                } label: {
                    HStack(spacing: 10) {
                        if isRefreshing {
                            ProgressView().tint(Theme.inkOnAccent)
                        }
                        Text(isRefreshing ? "Checking..." : "I verified my email")
                    }
                }
                .buttonStyle(AuthCTAButtonStyle(isBusy: isRefreshing))
                .disabled(isRefreshing)

                Button {
                    Task { await resend() }
                } label: {
                    Text(resendLabel)
                }
                .buttonStyle(AuthTextButtonStyle())
                .disabled(isResending || isInCooldown)

                Button(role: .destructive) {
                    appState.logout()
                } label: {
                    Text("Sign out")
                }
                .buttonStyle(AuthTextButtonStyle(weight: .regular, size: 15, color: Theme.muted))
            }
        }
        .task {
            await refresh()
        }
    }

    private var isInCooldown: Bool {
        guard let last = lastResendAt else { return false }
        return Date().timeIntervalSince(last) < resendCooldown
    }

    private var resendLabel: String {
        if isResending {
            return String(localized: "Sending...")
        }
        if isInCooldown, let last = lastResendAt {
            let remaining = Int(resendCooldown - Date().timeIntervalSince(last))
            return String(localized: "Resend in \(max(remaining, 1))s")
        }
        return String(localized: "Resend verification email")
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await appState.refreshCurrentUser()
        if !(appState.currentUser?.isEmailConfirmed ?? false) {
            statusMessage = String(localized: "Not verified yet. Check your inbox and tap the link.")
        } else {
            statusMessage = nil
        }
    }

    private func resend() async {
        guard !isInCooldown else { return }
        isResending = true
        defer { isResending = false }
        do {
            try await AuthService.resendConfirmation()
            lastResendAt = Date()
            statusMessage = String(localized: "Verification email sent.")
        } catch {
            statusMessage = String(localized: "Could not send email. Try again in a moment.")
        }
    }
}

#Preview("Verify email · light") {
    EmailVerificationGateView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Verify email · dark") {
    EmailVerificationGateView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Verify email · largest text") {
    EmailVerificationGateView()
        .environment(AppState())
        .dynamicTypeSize(.accessibility5)
}
