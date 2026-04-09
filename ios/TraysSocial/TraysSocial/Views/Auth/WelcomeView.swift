import SwiftUI
import AuthenticationServices

struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 32) {
                Spacer()

                // Logo
                VStack(spacing: 8) {
                    Text("Trays")
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(.white)

                    Text("Find something to eat")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Auth buttons
                VStack(spacing: 16) {
                    // Sign in with Apple
                    SignInWithAppleButton(.signIn) { request in
                        request.requestedScopes = [.email, .fullName]
                    } onCompletion: { result in
                        Task {
                            await viewModel.handleAppleSignIn(result: result, appState: appState)
                        }
                    }
                    .signInWithAppleButtonStyle(.white)
                    .frame(height: 50)
                    .cornerRadius(12)

                    // Email options
                    Button("Log in with email") {
                        showLogin = true
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(.white.opacity(0.1))
                    .cornerRadius(12)

                    Button("Create account") {
                        showRegister = true
                    }
                    .font(.body.weight(.medium))
                    .foregroundStyle(.orange)
                }
                .padding(.horizontal, 24)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                Spacer()
                    .frame(height: 40)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.black)
            .navigationDestination(isPresented: $showLogin) {
                LoginView(viewModel: viewModel)
            }
            .navigationDestination(isPresented: $showRegister) {
                RegisterView(viewModel: viewModel)
            }
            .sheet(isPresented: $viewModel.needsUsername) {
                UsernamePickerView(viewModel: viewModel)
            }
        }
    }
}
