import SwiftUI

struct EmailVerificationGateView: View {
    @Environment(AppState.self) private var appState
    @State private var isResending = false
    @State private var isRefreshing = false
    @State private var statusMessage: String?
    @State private var lastResendAt: Date?

    private let resendCooldown: TimeInterval = 60

    var body: some View {
        ZStack {
            Theme.background.ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "envelope.badge.shield.half.filled")
                    .font(.system(size: 64))
                    .foregroundStyle(Theme.accent)

                Text("Verify your email")
                    .font(.title.weight(.bold))
                    .foregroundStyle(Theme.text)

                VStack(spacing: 6) {
                    Text("We sent a verification link to")
                        .foregroundStyle(.secondary)

                    Text(appState.currentUser?.email ?? "your email")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(Theme.text)

                    Text("Tap the link in that email, then return here.")
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.top, 4)
                }
                .font(.subheadline)
                .padding(.horizontal, 32)

                if let message = statusMessage {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(Theme.accent)
                        .padding(.horizontal, 32)
                        .multilineTextAlignment(.center)
                }

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        HStack {
                            if isRefreshing { ProgressView().tint(.white) }
                            Text(isRefreshing ? "Checking..." : "I verified my email")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Theme.primary)
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .disabled(isRefreshing)

                    Button {
                        Task { await resend() }
                    } label: {
                        Text(resendLabel)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(Theme.primary)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .disabled(isResending || isInCooldown)

                    Button(role: .destructive) {
                        appState.logout()
                    } label: {
                        Text("Sign out")
                            .font(.subheadline.weight(.medium))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
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
        if isResending { return "Sending..." }
        if isInCooldown, let last = lastResendAt {
            let remaining = Int(resendCooldown - Date().timeIntervalSince(last))
            return "Resend in \(max(remaining, 1))s"
        }
        return "Resend verification email"
    }

    private func refresh() async {
        isRefreshing = true
        defer { isRefreshing = false }
        await appState.refreshCurrentUser()
        if !(appState.currentUser?.isEmailConfirmed ?? false) {
            statusMessage = "Not verified yet. Check your inbox and tap the link."
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
            statusMessage = "Verification email sent."
        } catch {
            statusMessage = "Could not send email. Try again in a moment."
        }
    }
}
