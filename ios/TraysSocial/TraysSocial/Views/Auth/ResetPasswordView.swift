import SwiftUI
import UIKit

/// W256: Reset your password and Check your email (Login artboard). The
/// user enters the email they sign in with and asks for a reset link; the
/// screen then shows the mint Check your email panel naming that address and
/// the one-hour window, Open Mail when a mail app can be opened, a Resend
/// link that waits 60 seconds after each send, and the footer back to Log
/// in. The emailed link opens the web set-password page; the user then logs
/// in here with the new password, so iOS never handles the reset token.
///
/// The copy never says whether an account exists. A failed send shows the
/// amber callout in place and never a toast.
struct ResetPasswordView: View {
    @State private var model: PasswordResetViewModel
    /// Footer link: swaps this screen for Log in.
    var onBackToLogIn: () -> Void

    @FocusState private var isEmailFocused: Bool
    @Environment(\.openURL) private var openURL
    @State private var canOpenMail = false

    private static let mailURL = URL(string: "message://")

    init(email: String, onBackToLogIn: @escaping () -> Void = {}) {
        _model = State(initialValue: PasswordResetViewModel(email: email))
        self.onBackToLogIn = onBackToLogIn
    }

    private var isSent: Bool {
        model.sentEmail != nil
    }

    private var isCompact: Bool {
        Self.usesCompactBand(isEmailFocused: isEmailFocused, isSent: isSent)
    }

    /// Keyboard up on the form: the band collapses to the compact bar and the
    /// heading and footer hide, so Send reset link stays above the keyboard.
    /// The sent state has no field, so it always shows the full band.
    static func usesCompactBand(isEmailFocused: Bool, isSent: Bool) -> Bool {
        isEmailFocused && !isSent
    }

    var body: some View {
        AuthScreen(band: .standard, isCompact: isCompact) {
            if !isCompact {
                AuthHeading(
                    title: "Reset your password",
                    subtitle: isSent
                        ? nil
                        : "Enter the email you use for Trays and we\u{2019}ll send you a link to set a new password."
                )
                .padding(.bottom, 24)
            }

            if isSent {
                sentState
            } else {
                formState
            }

            if !isCompact {
                Spacer(minLength: 24)
                AuthFooterLink(prompt: "Remembered it?", linkTitle: "Back to log in", action: onBackToLogIn)
            }
        }
        .authNavigationChrome()
        .onChange(of: model.email) { model.emailChanged() }
        .onChange(of: model.lastSentAt) { announceSent() }
        .onAppear { canOpenMail = Self.mailURL.map(UIApplication.shared.canOpenURL) ?? false }
    }

    // MARK: - Form

    private var formState: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                AuthFieldLabel("Email")
                TextField("Email", text: $model.email, prompt: .authEmailPrompt)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .submitLabel(.send)
                    .focused($isEmailFocused)
                    .onSubmit(send)
                    .authField(
                        isFocused: isEmailFocused,
                        needsAttention: model.emailNeedsAttention,
                        isBusy: model.isSending
                    )
            }

            if let error = model.errorMessage {
                AuthCallout(message: error)
            }

            // Enabled for a blank email so the tap can explain what is
            // missing; only an in-flight send disables it.
            Button(action: send) {
                if model.isSending {
                    AuthButtonSpinner(accessibilityLabel: "Sending reset link")
                } else {
                    Text("Send reset link")
                }
            }
            .buttonStyle(AuthCTAButtonStyle(isBusy: model.isSending))
        }
        .disabled(model.isSending)
    }

    // MARK: - Check your email

    private var sentState: some View {
        VStack(alignment: .leading, spacing: 16) {
            // The mint "Check your email" panel, as on the verify-email gate.
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: "envelope")
                    .scaledFont(18, weight: .semibold, relativeTo: .body)
                    .foregroundStyle(Theme.text)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 4) {
                    Text("Check your email")
                        .roundedFont(17, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)

                    Text(model.sentMessage ?? "")
                        .scaledFont(14.5, relativeTo: .subheadline)
                        .foregroundStyle(Theme.text)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(Theme.mintTint))
            .accessibilityElement(children: .combine)

            if let error = model.errorMessage {
                AuthCallout(message: error)
            }

            VStack(spacing: 12) {
                if canOpenMail, let mailURL = Self.mailURL {
                    Button {
                        openURL(mailURL)
                    } label: {
                        Text("Open Mail")
                    }
                    .buttonStyle(AuthCTAButtonStyle())
                }

                // Redraws once a second so the countdown and the enabled
                // state follow the clock.
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    Button {
                        Task { await model.resend() }
                    } label: {
                        Text(resendLabel)
                    }
                    .buttonStyle(AuthTextButtonStyle())
                    .disabled(!model.canResend)
                }
            }
        }
    }

    private var resendLabel: String {
        if model.isSending {
            return String(localized: "Sending...")
        }
        let remaining = model.resendSecondsRemaining
        if remaining > 0 {
            return String(localized: "Resend in \(remaining)s")
        }
        return String(localized: "Resend link")
    }

    // MARK: - Actions

    private func send() {
        guard !model.isSending else { return }
        isEmailFocused = false
        Task { await model.sendResetLink() }
    }

    /// The panel replaces the form without moving focus, so say what
    /// happened; this also covers each resend.
    private func announceSent() {
        guard let announcement = model.sentAnnouncement else { return }
        AccessibilityNotification.Announcement(announcement).post()
    }
}

#Preview("Reset password · light") {
    NavigationStack {
        ResetPasswordView(email: "cook@example.com")
    }
    .preferredColorScheme(.light)
}

#Preview("Reset password · dark") {
    NavigationStack {
        ResetPasswordView(email: "")
    }
    .preferredColorScheme(.dark)
}

#Preview("Reset password · largest text") {
    NavigationStack {
        ResetPasswordView(email: "cook@example.com")
    }
    .dynamicTypeSize(.accessibility5)
}
