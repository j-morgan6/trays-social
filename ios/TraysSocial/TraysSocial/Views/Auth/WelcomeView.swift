import AuthenticationServices
import SwiftUI

/// Editorial welcome / sign-in entry — restyled to match the editorial
/// system. The web app has a dedicated `/welcome` (three trays
/// explained) shown post-signup; the iOS post-signup welcome isn't
/// wired yet (would need `seen_welcome_at` exposed on /auth/me). This
/// view stays the sign-in landing for now.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 0) {
                hero
                    .padding(.bottom, 32)

                pitch
                    .padding(.horizontal, 24)

                Spacer(minLength: 0)

                authActions
                    .padding(.horizontal, 24)

                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .padding(.top, 12)
                }

                if let error = viewModel.errorMessage {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                }

                LegalAcceptanceFooter()
                    .padding(.top, 14)

                Spacer().frame(height: 24)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.background)
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

    // MARK: - Hero

    /// Warm gradient placeholder — sits in for the food photo the
    /// design's IOSSignin uses. Real photography goes here when it's
    /// available.
    private var hero: some View {
        LinearGradient(
            colors: [Color(hex: 0xD8B178), Color(hex: 0xC08A4F), Color(hex: 0x8A5A32)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: 320)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Pitch

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trays")
                .font(.serif(22))
                .foregroundStyle(Theme.secondary)

            Text("A quiet place\nto cook from.")
                .font(.serif(38))
                .foregroundStyle(Theme.text)
                .lineSpacing(-4)
                .tracking(-0.5)

            Text("Recipes from home cooks who actually cook. Ingredients, timing, method — written down well.")
                .font(.system(size: 14))
                .foregroundStyle(Theme.textSecondary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Auth actions

    private var authActions: some View {
        VStack(spacing: 12) {
            SignInWithAppleButton(.signIn) { request in
                // W104: per-attempt nonce, see AuthViewModel.
                viewModel.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task {
                    await viewModel.handleAppleSignIn(result: result, appState: appState)
                }
            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 52)
            .cornerRadius(26)

            Button {
                showRegister = true
            } label: {
                Text("Create an account")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x2A1C00))
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(Theme.accent)
                    .clipShape(Capsule())
            }
            .buttonStyle(.plain)

            Button {
                showLogin = true
            } label: {
                Text("I already have an account")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
        }
    }
}
