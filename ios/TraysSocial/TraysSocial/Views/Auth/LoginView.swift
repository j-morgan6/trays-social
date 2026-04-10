import SwiftUI

struct LoginView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Log in")
                .font(.title.bold())
                .foregroundStyle(.white)

            VStack(spacing: 16) {
                TextField("Email", text: $viewModel.email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(.white.opacity(0.08))
                    .cornerRadius(12)

                SecureField("Password", text: $viewModel.password)
                    .textContentType(.password)
                    .padding()
                    .background(.white.opacity(0.08))
                    .cornerRadius(12)
            }

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
            .background(viewModel.canLogin ? Theme.accent : .gray.opacity(0.3))
            .cornerRadius(12)
            .disabled(!viewModel.canLogin)

            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .onDisappear { viewModel.clearError() }
    }
}
