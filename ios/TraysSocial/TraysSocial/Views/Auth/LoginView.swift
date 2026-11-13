import SwiftUI

/// W251: Log in on the redesign canvas (Login artboard): the emerald band,
/// a rounded sheet with labelled fields, the Remember me switch, one amber
/// callout above an amber Log in button, Face ID under an "or" rule when a
/// saved credential exists, and a footer link to Create account. While a
/// field is focused the band collapses to a compact bar. The view model,
/// its validation and the login calls are unchanged.
struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel
    /// Footer link: swaps this screen for Create account.
    var onCreateAccount: () -> Void = {}
    /// W256: Forgot password? on the Password label row: opens Reset your
    /// password with the typed email prefilled.
    var onForgotPassword: () -> Void = {}

    private enum Field: Hashable {
        case email
        case password
    }

    @FocusState private var focusedField: Field?

    var body: some View {
        AuthScreen(band: .standard, isCompact: focusedField != nil) {
            if focusedField == nil {
                AuthHeading(title: "Welcome back", subtitle: "Log in to get back to your tray.")
                    .padding(.bottom, 24)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    AuthFieldLabel("Email")
                    TextField("Email", text: $viewModel.email, prompt: .authEmailPrompt)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .email)
                        .onSubmit { focusedField = .password }
                        .authField(isFocused: focusedField == .email, isBusy: viewModel.isLoading)
                }

                VStack(alignment: .leading, spacing: 0) {
                    passwordLabelRow
                    SecureField("Password", text: $viewModel.password, prompt: .authPrompt("Your password"))
                        .textContentType(.password)
                        .submitLabel(.go)
                        .focused($focusedField, equals: .password)
                        .onSubmit(submit)
                        .authField(isFocused: focusedField == .password, isBusy: viewModel.isLoading)
                }

                AuthSwitchRow(
                    title: "Remember me",
                    subtitle: "Use Face ID next time",
                    isOn: $viewModel.rememberMe
                )

                if let error = viewModel.errorMessage, !viewModel.isLoading {
                    AuthCallout(message: error)
                }

                Button(action: submit) {
                    if viewModel.isLoading {
                        AuthButtonSpinner(accessibilityLabel: "Logging in")
                    } else {
                        Text("Log in")
                    }
                }
                .buttonStyle(AuthCTAButtonStyle(isBusy: viewModel.isLoading))
                .disabled(!viewModel.canLogin)

                if viewModel.hasSavedCredential, focusedField == nil {
                    AuthOrDivider()
                    Button {
                        Task { await viewModel.loginWithBiometrics(appState: appState) }
                    } label: {
                        Label("Sign in with Face ID", systemImage: "faceid")
                    }
                    .buttonStyle(AuthOutlineButtonStyle())
                    .disabled(viewModel.isLoading)
                }
            }
            .disabled(viewModel.isLoading)

            if focusedField == nil {
                Spacer(minLength: 24)
                AuthFooterLink(prompt: "New here?", linkTitle: "Create an account", action: onCreateAccount)
                LoginSupportLine()
            }
        }
        .authNavigationChrome()
        // Canvas: the callout clears as soon as either field is edited.
        .onChange(of: viewModel.email) { clearErrorIfShown() }
        .onChange(of: viewModel.password) { clearErrorIfShown() }
        .onAppear { viewModel.checkBiometricAvailability() }
        .onDisappear { viewModel.clearError() }
    }

    /// The Password label with Forgot password? right aligned (Login
    /// artboard: 14 semibold link, 44pt hit). The 44pt frame is taller than
    /// the label, so the row starts 8pt higher to keep the label's rhythm
    /// close to the Email group's. At the largest text sizes the link wraps
    /// under the label instead of squeezing it.
    private var passwordLabelRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 12) {
                AuthFieldLabel("Password")
                Spacer(minLength: 0)
                forgotPasswordLink
            }
            VStack(alignment: .leading, spacing: 0) {
                AuthFieldLabel("Password")
                forgotPasswordLink
            }
        }
        .padding(.top, -8)
    }

    private var forgotPasswordLink: some View {
        Button(action: onForgotPassword) {
            Text("Forgot password?")
                .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func submit() {
        guard viewModel.canLogin else { return }
        focusedField = nil
        Task { await viewModel.login(appState: appState) }
    }

    private func clearErrorIfShown() {
        if viewModel.errorMessage != nil, !viewModel.isLoading {
            viewModel.clearError()
        }
    }
}

/// W263: Trouble signing in? under the footer, for people who cannot sign
/// in and so cannot reach the in-app feedback sheet. The address is the one
/// published in the privacy policy. It is a mail link; with no mail app the
/// address is still on screen, and a long press offers Copy email address
/// (a Link label cannot take text selection, so Copy stands in for it).
struct LoginSupportLine: View {
    static let supportEmail = "support@trays.app"
    static let mailURL = URL(string: "mailto:support@trays.app")!

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { content }
            VStack(spacing: 0) { content }
        }
        .frame(maxWidth: .infinity)
    }

    /// Copy email address, for people with no mail app set up.
    static func copyAddress(to pasteboard: UIPasteboard = .general) {
        pasteboard.string = supportEmail
    }

    @ViewBuilder private var content: some View {
        Text("Trouble signing in?")
            .scaledFont(15, relativeTo: .subheadline)
            .foregroundStyle(Theme.muted)
        Link(destination: Self.mailURL) {
            Text(verbatim: Self.supportEmail)
                .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .contextMenu {
            Button {
                Self.copyAddress()
            } label: {
                Label("Copy email address", systemImage: "doc.on.doc")
            }
        }
    }
}

extension View {
    /// Pushed auth screens: the navigation bar stays (so the system back
    /// button and swipe-back keep working) but draws no background, and its
    /// back button is cream over the emerald band.
    func authNavigationChrome() -> some View {
        toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationBarTitleDisplayMode(.inline)
            .tint(Theme.cream)
    }
}

#Preview("Log in · light") {
    NavigationStack {
        LoginView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.light)
}

#Preview("Log in · dark") {
    NavigationStack {
        LoginView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Log in · largest text") {
    NavigationStack {
        LoginView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .dynamicTypeSize(.accessibility5)
}
