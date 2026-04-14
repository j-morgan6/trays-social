import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Log in")
                .font(.title.bold())
                .foregroundStyle(Theme.text)

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
                .font(.subheadline)
                .foregroundStyle(Theme.text)
                .tint(Theme.primary)

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.login(appState: appState) }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Log in")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(viewModel.canLogin ? Theme.primary : .gray.opacity(0.3))
            .cornerRadius(12)
            .disabled(!viewModel.canLogin)

            if viewModel.hasSavedCredential {
                Button {
                    Task { await viewModel.loginWithBiometrics(appState: appState) }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "faceid")
                        Text("Sign in with Face ID")
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(Theme.primary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Theme.surface)
                    .cornerRadius(12)
                }
                .disabled(viewModel.isLoading)
            }

            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .onAppear { viewModel.checkBiometricAvailability() }
        .onDisappear { viewModel.clearError() }
    }
}
