import AuthenticationServices
import SwiftUI

/// Welcome / sign-in entry. Recreates the Claude Design "Trays — Welcome /
/// Sign-up" handoff: an emerald hero band (wordmark + eyebrow), a stage that
/// floats the divided-tray illustration (a riff on the app icon, built from
/// native shapes — no image asset), and a pinned action stack (Sign in with
/// Apple, Create an account, log into an existing account) over the legal
/// line.
///
/// The auth wiring (Apple sign-in, register/login navigation, username
/// picker, suspension alert) is unchanged from the prior version — only the
/// visual layer was redesigned. The web app has a separate post-signup
/// `/welcome`; this view stays the sign-in landing.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @State private var viewModel = AuthViewModel()
    @State private var showLogin = false
    @State private var showRegister = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                hero

                // Stage — flexes to fill the space between the hero and the
                // actions, centering the floating tray on the off-white base.
                trayIllustration
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.horizontal, 24)

                authActions
                    .padding(.horizontal, 30)
                    .padding(.bottom, 18)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Theme.bgLight)
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

    /// Emerald hero band, ~232pt tall, with the cream wordmark and the gold
    /// eyebrow centered. Only the green background bleeds under the status
    /// bar (`ignoresSafeArea`); the text stays centered within the visible
    /// band below the safe area.
    private var hero: some View {
        VStack(spacing: 11) {
            Text("Trays")
                .font(.system(size: 58, weight: .heavy))
                .tracking(-2.32)
                .foregroundStyle(Theme.cream)

            Text("RECIPES WORTH KEEPING")
                .font(.system(size: 12, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(Theme.gold)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 232)
        .background(Theme.primary.ignoresSafeArea(edges: .top))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Trays. Recipes worth keeping.")
    }

    // MARK: - Tray illustration

    /// Fixed geometry from the handoff: 338pt wide, 1.46:1 aspect, 5pt emerald
    /// border, 30pt radius, 14pt inner padding, 14pt grid gap, columns 0.9fr /
    /// 1.1fr. 338pt fits every iOS 17 device (smallest is 375pt wide). Widths
    /// are computed explicitly rather than via flexible frames so a wide child
    /// can't stretch the layout (`.frame(maxWidth:.infinity)` does not cap).
    private var trayIllustration: some View {
        let trayWidth: CGFloat = 338
        let trayHeight = trayWidth / 1.46
        let border: CGFloat = 5
        let inset: CGFloat = 14
        let gap: CGFloat = 14
        let innerWidth = trayWidth - (border * 2) - (inset * 2)
        let leftColumn = (innerWidth - gap) * 0.9 / 2.0
        let rightColumn = (innerWidth - gap) * 1.1 / 2.0

        return HStack(spacing: gap) {
            VStack(spacing: gap) {
                compartment("Recipes", fill: Theme.secondary, foreground: Theme.primary)
                friendsCompartment
            }
            .frame(width: leftColumn)

            compartment("A Quiet Place to Cook", fill: Theme.primary, foreground: Theme.cream)
                .frame(width: rightColumn)
        }
        .padding(inset)
        .frame(width: trayWidth, height: trayHeight)
        .background(RoundedRectangle(cornerRadius: 30, style: .continuous).fill(Theme.cream))
        .overlay(
            RoundedRectangle(cornerRadius: 30, style: .continuous)
                .strokeBorder(Theme.primary, lineWidth: border)
        )
        .shadow(color: Color(hex: 0x143C14).opacity(0.26), radius: 18, x: 0, y: 12)
        .shadow(color: Color(hex: 0x143C14).opacity(0.14), radius: 5, x: 0, y: 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recipes, friends, and a quiet place to cook.")
    }

    /// A filled tray compartment with a centered label. Rounded 18pt with a
    /// hairline inner stroke standing in for the design's subtle inset shadow.
    private func compartment(_ title: String, fill: Color, foreground: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill)
            Text(title)
                .font(.system(size: 17, weight: .bold))
                .tracking(-0.26)
                .lineSpacing(2)
                .multilineTextAlignment(.center)
                .foregroundStyle(foreground)
                .padding(.horizontal, 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.black.opacity(0.04), lineWidth: 1)
        )
    }

    /// Bottom-left cell: transparent (shows the cream base), with a centered
    /// amber circle whose diameter tracks the cell height (aspect 1).
    private var friendsCompartment: some View {
        Color.clear
            .overlay {
                ZStack {
                    Circle().fill(Theme.accent)
                    Text("Friends")
                        .font(.system(size: 17, weight: .bold))
                        .tracking(-0.26)
                        .foregroundStyle(Theme.textLight)
                }
                .overlay(Circle().strokeBorder(Color.black.opacity(0.05), lineWidth: 1))
                .aspectRatio(1, contentMode: .fit)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Auth actions

    private var authActions: some View {
        VStack(spacing: 10) {
            // D75: the 13+ affirmation Toggle used to gate Apple Sign In here.
            // It was moved out of the login path entirely — affirmation is
            // collected at account creation (RegisterView keeps its toggle for
            // email signup) and via the implicit consent of tapping Apple Sign
            // In here. AuthViewModel always sends ageConfirmation: true; the
            // server requires the affirmation only on new-user account creation
            // via apple_id and is a no-op for returning users.
            SignInWithAppleButton(.signIn) { request in
                // W104: per-attempt nonce, see AuthViewModel.
                viewModel.prepareAppleSignInRequest(request)
            } onCompletion: { result in
                Task {
                    await viewModel.handleAppleSignIn(result: result, appState: appState)
                }
            }
            .signInWithAppleButtonStyle(.black)
            .frame(height: 54)
            .clipShape(Capsule())
            .accessibilityHint("Sign in with your Apple ID")

            Button {
                showRegister = true
            } label: {
                Text("Create an account")
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(-0.17)
                    .foregroundStyle(Theme.textLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Theme.accent)
                    .clipShape(Capsule())
                    .shadow(color: Theme.accent.opacity(0.38), radius: 10, x: 0, y: 8)
                    .shadow(color: Theme.accent.opacity(0.30), radius: 2, x: 0, y: 2)
            }
            .buttonStyle(.plain)

            Button {
                showLogin = true
            } label: {
                Text("I already have an account")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Theme.textLight)
                    .frame(maxWidth: .infinity)
                    .frame(height: 48)
            }
            .buttonStyle(.plain)

            if viewModel.isLoading {
                ProgressView()
                    .tint(Theme.primary)
                    .padding(.top, 4)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
                    .padding(.top, 4)
            }

            LegalAcceptanceFooter()
                .padding(.top, 6)
        }
    }
}
