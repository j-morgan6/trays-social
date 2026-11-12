import SwiftUI

/// The username sheet after a first Sign in with Apple. W251: restyled to
/// match the redesigned sign-in screens (rounded heading, the shared field
/// box, an amber note under the field, the amber Continue button). The
/// view model and `setUsername` are unchanged.
struct UsernamePickerView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel
    @FocusState private var isFocused: Bool

    private var needsAttention: Bool {
        !viewModel.username.isEmpty && !viewModel.isUsernameValid
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                AuthHeading(
                    title: "Choose a username",
                    subtitle: "This is how other cooks will find you on Trays."
                )

                VStack(alignment: .leading, spacing: 8) {
                    AuthFieldLabel("Username")
                    TextField("Username", text: $viewModel.username, prompt: .authPrompt("Username"))
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .focused($isFocused)
                        .authField(
                            isFocused: isFocused,
                            needsAttention: needsAttention,
                            isBusy: viewModel.isLoading
                        )

                    if needsAttention {
                        EditorAttentionNote(
                            message: String(localized: "3-30 characters, letters, numbers, underscores only")
                        )
                    }
                }

                if let error = viewModel.errorMessage, !viewModel.isLoading {
                    AuthCallout(message: error)
                }

                Button {
                    Task { await viewModel.setUsername(appState: appState) }
                } label: {
                    if viewModel.isLoading {
                        AuthButtonSpinner(accessibilityLabel: "Saving your username")
                    } else {
                        Text("Continue")
                    }
                }
                .buttonStyle(AuthCTAButtonStyle(isBusy: viewModel.isLoading))
                .disabled(!viewModel.isUsernameValid || viewModel.isLoading)
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Theme.background.ignoresSafeArea())
        .interactiveDismissDisabled()
    }
}

#Preview("Username · light") {
    Color.clear.sheet(isPresented: .constant(true)) {
        UsernamePickerView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.light)
}

#Preview("Username · dark") {
    Color.clear.sheet(isPresented: .constant(true)) {
        UsernamePickerView(viewModel: AuthViewModel())
    }
    .environment(AppState())
    .preferredColorScheme(.dark)
}
