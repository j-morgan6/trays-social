import SwiftUI

/// W251: Create account on the redesign canvas (Login artboard, "Create
/// account"): the same band, sheet, fields and amber button as Log in.
/// Field problems sit under their field as an amber note and give the field
/// an amber ring; the password rule shows as a quiet hint before any error.
/// The 13+ confirmation is a switch row, and Create account stays disabled
/// until the view model's `canRegister`. Username suggestions are drawn on
/// the canvas but are an unscheduled idea (spec D16), so a taken name still
/// shows only the server's message.
struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel
    /// Footer link: swaps this screen for Log in.
    var onLogIn: () -> Void = {}

    private enum Field: Hashable {
        case username
        case email
        case password
    }

    @FocusState private var focusedField: Field?

    private var usernameNeedsAttention: Bool {
        !viewModel.username.isEmpty && !viewModel.isUsernameValid
    }

    private var passwordNeedsAttention: Bool {
        !viewModel.password.isEmpty && !viewModel.isPasswordValid
    }

    var body: some View {
        AuthScreen(band: .standard, isCompact: focusedField != nil) {
            if focusedField == nil {
                AuthHeading(title: "Start your tray", subtitle: "Save recipes you love and share your own.")
                    .padding(.bottom, 24)
            }

            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    AuthFieldLabel("Username")
                    TextField("Username", text: $viewModel.username, prompt: .authPrompt("Username"))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .submitLabel(.next)
                        .focused($focusedField, equals: .username)
                        .onSubmit { focusedField = .email }
                        .authField(
                            isFocused: focusedField == .username,
                            needsAttention: usernameNeedsAttention,
                            isBusy: viewModel.isLoading
                        )

                    if usernameNeedsAttention {
                        EditorAttentionNote(
                            message: String(localized: "3-30 characters, letters, numbers, underscores only")
                        )
                    }
                }

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

                VStack(alignment: .leading, spacing: 8) {
                    AuthFieldLabel("Password")
                    SecureField("Password", text: $viewModel.password, prompt: .authPrompt("Password"))
                        .textContentType(.newPassword)
                        .submitLabel(.done)
                        .focused($focusedField, equals: .password)
                        .onSubmit { focusedField = nil }
                        .authField(
                            isFocused: focusedField == .password,
                            needsAttention: passwordNeedsAttention,
                            isBusy: viewModel.isLoading
                        )

                    if passwordNeedsAttention {
                        EditorAttentionNote(message: String(localized: "Must be at least 12 characters"))
                    } else {
                        Text("At least 12 characters.")
                            .scaledFont(13, relativeTo: .footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }

                AuthSwitchRow(title: "I confirm I am 13 years old or older.", isOn: $viewModel.ageConfirmed)
                    .accessibilityIdentifier("age-confirmation-toggle")
                    .accessibilityHint("Required to register an account")

                if let error = viewModel.errorMessage, !viewModel.isLoading {
                    AuthCallout(message: error)
                }

                Button {
                    focusedField = nil
                    Task { await viewModel.register(appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        AuthButtonSpinner(accessibilityLabel: "Creating your account")
                    } else {
                        Text("Create account")
                    }
                }
                .buttonStyle(AuthCTAButtonStyle(isBusy: viewModel.isLoading))
                .disabled(!viewModel.canRegister)

                LegalAcceptanceFooter()
            }
            .disabled(viewModel.isLoading)

            if focusedField == nil {
                Spacer(minLength: 24)
                AuthFooterLink(prompt: "Already have an account?", linkTitle: "Log in", action: onLogIn)
            }
        }
        .authNavigationChrome()
        .onDisappear { viewModel.clearError() }
    }
}

#Preview("Create account · light") {
    NavigationStack {
        RegisterView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.light)
}

#Preview("Create account · dark") {
    NavigationStack {
        RegisterView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}

#Preview("Create account · largest text") {
    NavigationStack {
        RegisterView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .dynamicTypeSize(.accessibility5)
}
