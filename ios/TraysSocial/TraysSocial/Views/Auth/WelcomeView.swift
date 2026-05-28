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
            // Surfaces a one-shot suspension alert after the user is logged
            // out by AppState.handleSuspended (either from a fresh login
            // attempt or a mid-session 403). The .alert is bound to a
            // computed isPresented so dismissing it clears the message and
            // prevents re-firing on every re-render.
            .alert("Account suspended", isPresented: suspensionAlertBinding) {
                Button("OK", role: .cancel) {
                    appState.clearSuspensionMessage()
                }
            } message: {
                Text(appState.suspensionMessage ?? "")
            }
        }
    }

    private var suspensionAlertBinding: Binding<Bool> {
        Binding(
            get: { appState.suspensionMessage != nil },
            set: { presented in
                if !presented { appState.clearSuspensionMessage() }
            }
        )
    }

    // MARK: - Hero

    /// D96: amber palette hero pulled from Theme tokens (matches the
    /// rest of the app's accent family). Still a placeholder for a
    /// curated food photo, but the colors are no longer off-palette,
    /// the height is reduced from 320pt to 240pt so the pitch + buttons
    /// take a larger share of the screen, and a centered wordmark
    /// "Trays" sits inside the gradient so the block doesn't read as
    /// empty. Real photography lands here when a curated asset is
    /// shipped.
    private var hero: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Theme.accent,
                    Theme.accentInkLight,
                    Theme.accentMuted,
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            Text("Trays")
                .font(.system(size: 44, weight: .bold))
                .tracking(-0.88)
                .foregroundStyle(Theme.inkOnAccent)
                .accessibilityHidden(true)
        }
        .frame(height: 240)
        .ignoresSafeArea(edges: .top)
    }

    // MARK: - Pitch

    private var pitch: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Trays")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Theme.secondary)

            Text("A quiet place\nto cook from.")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Theme.text)
                .lineSpacing(-4)

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
            // D75: the 13+ affirmation Toggle used to live above this
            // button to gate Apple Sign In. Returning users saw it on
            // every Welcome visit (the client can't know they're
            // returning until the server resolves the apple_id post-
            // tap), which the user reported as friction. Moved out of
            // the login path entirely — affirmation is collected at
            // account creation (RegisterView keeps its toggle for
            // email signup) and via the implicit consent of tapping
            // Apple Sign In here. AuthViewModel always sends
            // ageConfirmation: true; the server's existing logic
            // requires the affirmation only on new-user account
            // creation via apple_id and is a no-op for returning
            // users.
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
            .accessibilityHint("Sign in with your Apple ID")

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
