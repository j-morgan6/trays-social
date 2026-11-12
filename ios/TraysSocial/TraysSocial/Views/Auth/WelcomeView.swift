import AuthenticationServices
import SwiftUI

/// Welcome / sign-in entry. W251: rebuilt on the redesign canvas (Login
/// artboard, "Welcome"): the tall emerald band with the handles logo, the
/// rounded sheet with "A quiet place to cook." and three tiles that echo the
/// logo's compartments, then the action stack pinned to the bottom (Sign in
/// with Apple, the amber Create an account, I already have an account) over
/// the legal line.
///
/// The auth wiring (Apple sign-in, register/login navigation, username
/// picker, suspension alert) is unchanged; only the visual layer changed.
/// Navigation moved from two flags to a path so the footer links on Log in
/// and Create account can swap one for the other in place. The web app has
/// a separate post-signup `/welcome`; this view stays the sign-in landing.
struct WelcomeView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @State private var viewModel = AuthViewModel()
    @State private var path: [AuthRoute] = []

    enum AuthRoute: Hashable {
        case login
        case register
    }

    /// The path that shows `route`. Every entry point, the footer links on
    /// Log in and Create account included, replaces the path rather than
    /// pushing onto it, so switching between the two never stacks screens
    /// and Back always returns to Welcome.
    static func path(showing route: AuthRoute) -> [AuthRoute] {
        [route]
    }

    var body: some View {
        NavigationStack(path: $path) {
            AuthScreen(band: .hero) {
                Text("A quiet place to cook.")
                    .roundedFont(30, weight: .heavy, relativeTo: .largeTitle)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)

                featureTiles
                    .padding(.top, 18)

                Spacer(minLength: 24)

                authActions
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
            .navigationDestination(for: AuthRoute.self) { route in
                switch route {
                case .login:
                    LoginView(viewModel: viewModel, onCreateAccount: { path = Self.path(showing: .register) })
                case .register:
                    RegisterView(viewModel: viewModel, onLogIn: { path = Self.path(showing: .login) })
                }
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
                if !presented {
                    appState.clearSuspensionMessage()
                }
            }
        )
    }

    // MARK: - Feature tiles

    /// Three tiles in place of the old tray illustration: mint tint, amber
    /// muted and cream (lift in dark), 18pt corners, at least 96pt high, one
    /// shared height. At the accessibility text sizes they stack.
    @ViewBuilder private var featureTiles: some View {
        if dynamicTypeSize.isAccessibilitySize {
            VStack(spacing: 10) { tiles }
        } else {
            HStack(alignment: .top, spacing: 10) { tiles }
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder private var tiles: some View {
        featureTile("Keep the recipes you love", systemImage: "book.closed", fill: Theme.mintTint)
        featureTile("See what friends cook", systemImage: "person.2", fill: Theme.accentMuted)
        featureTile("Cook from what you have", systemImage: "refrigerator", fill: Theme.creamOrLift)
    }

    private func featureTile(_ title: LocalizedStringKey, systemImage: String, fill: Color) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: systemImage)
                .scaledFont(18, weight: .semibold, relativeTo: .body)
                .accessibilityHidden(true)
            Text(title)
                .roundedFont(14, weight: .heavy, relativeTo: .subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, minHeight: 96, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 18, style: .continuous).fill(fill))
        .accessibilityElement(children: .combine)
    }

    // MARK: - Auth actions

    private var authActions: some View {
        VStack(spacing: 12) {
            if let error = viewModel.errorMessage, !viewModel.isLoading {
                AuthCallout(message: error)
            }

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
            .appleButtonStyleForScheme()
            .frame(height: 54)
            .clipShape(Capsule())
            .accessibilityHint("Sign in with your Apple ID")

            Button {
                path = Self.path(showing: .register)
            } label: {
                Text("Create an account")
            }
            .buttonStyle(AuthCTAButtonStyle())

            Button {
                path = Self.path(showing: .login)
            } label: {
                Text("I already have an account")
            }
            .buttonStyle(AuthTextButtonStyle())

            if viewModel.isLoading {
                ProgressView()
                    .tint(Theme.primaryInk)
            }

            LegalAcceptanceFooter()
                .padding(.top, 6)
        }
    }
}

private extension View {
    /// Apple's black button in light mode and its white button in dark mode,
    /// as Apple's guidelines ask (Login artboard, "Welcome").
    func appleButtonStyleForScheme() -> some View {
        modifier(AppleButtonSchemeStyle())
    }
}

private struct AppleButtonSchemeStyle: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        content
            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
            // The style is read when the button is created; rebuild it when
            // the appearance changes. Known edge: an appearance change while
            // Apple's sheet is open (automatic dark mode at sunset) rebuilds
            // the button mid-request; accepted, since the user can tap again.
            .id(colorScheme)
    }
}

#Preview("Welcome · light") {
    WelcomeView()
        .environment(AppState())
        .preferredColorScheme(.light)
}

#Preview("Welcome · dark") {
    WelcomeView()
        .environment(AppState())
        .preferredColorScheme(.dark)
}

#Preview("Welcome · largest text") {
    WelcomeView()
        .environment(AppState())
        .dynamicTypeSize(.accessibility5)
}
