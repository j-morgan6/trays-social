import SwiftUI

/// W139: restyled to match the editorial system. Serif heading, Theme
/// tokens for colors, and amber `Theme.accent` capsule button matching
/// `BottomPill`'s Create FAB.
struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("New here")
                        .font(.serif(22))
                        .foregroundStyle(Theme.secondary)

                    Text("Create an account")
                        .font(.serif(38))
                        .foregroundStyle(Theme.text)
                        .tracking(-0.5)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.top, 8)

                VStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 4) {
                        TextField("Username", text: $viewModel.username)
                            .textContentType(.username)
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)

                        if !viewModel.username.isEmpty, !viewModel.isUsernameValid {
                            Text("3-30 characters, letters, numbers, underscores only")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    TextField("Email", text: $viewModel.email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)

                    VStack(alignment: .leading, spacing: 4) {
                        SecureField("Password", text: $viewModel.password)
                            .textContentType(.newPassword)
                            .padding()
                            .background(Theme.surface)
                            .cornerRadius(12)

                        if !viewModel.password.isEmpty, !viewModel.isPasswordValid {
                            Text("Must be at least 12 characters")
                                .font(.caption2)
                                .foregroundStyle(.red)
                        }
                    }

                    Toggle(isOn: $viewModel.ageConfirmed) {
                        Text("I confirm I am 13 years old or older.")
                            .font(.system(size: 14))
                            .foregroundStyle(Theme.textSecondary)
                    }
                    .tint(Theme.accent)
                    .padding(.horizontal, 4)
                    .accessibilityIdentifier("age-confirmation-toggle")
                    .accessibilityHint("Required to register an account")
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                }

                Button {
                    Task { await viewModel.register(appState: appState) }
                } label: {
                    Group {
                        if viewModel.isLoading {
                            ProgressView().tint(Color(hex: 0x2A1C00))
                        } else {
                            Text("Create account")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color(hex: 0x2A1C00))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(viewModel.canRegister ? Theme.accent : Theme.surface)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(!viewModel.canRegister)

                LegalAcceptanceFooter()
                    .padding(.top, 4)

                Spacer(minLength: 32)
            }
            .padding(.horizontal, 24)
            .padding(.top, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .background(Theme.background)
        .onDisappear { viewModel.clearError() }
    }
}
