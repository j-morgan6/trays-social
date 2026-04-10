import SwiftUI

struct RegisterView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Create account")
                .font(.title.bold())
                .foregroundStyle(Theme.text)

            VStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    TextField("Username", text: $viewModel.username)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                        .padding()
                        .background(Theme.surface)
                        .cornerRadius(12)

                    if !viewModel.username.isEmpty && !viewModel.isUsernameValid {
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

                    if !viewModel.password.isEmpty && !viewModel.isPasswordValid {
                        Text("Must be at least 12 characters")
                            .font(.caption2)
                            .foregroundStyle(.red)
                    }
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Button {
                Task { await viewModel.register(appState: appState) }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Create account")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(viewModel.canRegister ? Theme.primary : .gray.opacity(0.3))
            .cornerRadius(12)
            .disabled(!viewModel.canRegister)

            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .onDisappear { viewModel.clearError() }
    }
}
