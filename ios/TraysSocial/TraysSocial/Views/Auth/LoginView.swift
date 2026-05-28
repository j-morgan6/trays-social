import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Welcome back")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.secondary)

                Text("Log in")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(Theme.text)
            }
            .padding(.top, 12)

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(12)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(12)
            }

            Toggle("Remember me", isOn: $viewModel.rememberMe)
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .tint(Theme.accent)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: .infinity)
            }

            Button {
                Task { await viewModel.login(appState: appState) }
            } label: {
                Group {
                    if viewModel.isLoading {
                        ProgressView().tint(Color(hex: 0x2A1C00))
                    } else {
                        Text("Log in")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundStyle(Color(hex: 0x2A1C00))
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(viewModel.canLogin ? Theme.accent : Theme.surface)
                .clipShape(Capsule())
            }
            .buttonStyle(.plain)
            .disabled(!viewModel.canLogin)

            if viewModel.hasSavedCredential {
                Button {
                    Task { await viewModel.loginWithBiometrics(appState: appState) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Sign in with Face ID")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.surface)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isLoading)
            }

            Spacer()
        }
        .padding(.horizontal, 24)
        .padding(.top, 16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.background)
        .onAppear { viewModel.checkBiometricAvailability() }
        .onDisappear { viewModel.clearError() }
    }
}
