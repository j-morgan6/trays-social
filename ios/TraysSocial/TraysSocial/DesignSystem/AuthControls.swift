import SwiftUI

// W251: the redesigned sign-in chrome (Login artboard). The emerald band
// with the handles logo, the rounded sheet that overlaps it, the field
// label, the amber call to action, the quiet outline and text buttons, the
// switch row, the amber error callout and the footer link. Shared by
// Welcome, Log in, Create account, the username sheet and the verify-email
// gate. Visual only: the auth view model and its flows are unchanged.

/// Which band an auth screen shows above its sheet.
enum AuthBandStyle {
    /// Welcome: a taller band with a larger logo and wordmark.
    case hero
    /// Log in, Create account and the verify-email gate.
    case standard
}

/// An auth screen: the band (or, while typing, the compact bar) over a
/// rounded sheet on the page background. The band bleeds under the status
/// bar, the page scrolls, and the sheet fills the rest of the screen so a
/// trailing `Spacer` pins the footer to the bottom.
struct AuthScreen<Content: View>: View {
    var band: AuthBandStyle = .standard
    /// Keyboard up: the band collapses to a 56pt bar and the sheet loses
    /// its rounded top so the focused field and the button stay in view.
    var isCompact = false
    @ViewBuilder var content: Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { proxy in
            let topInset = proxy.safeAreaInsets.top
            ScrollView {
                VStack(spacing: 0) {
                    if isCompact {
                        AuthCompactBar(topInset: topInset)
                    } else {
                        AuthBand(style: band, topInset: topInset)
                    }

                    VStack(alignment: .leading, spacing: 0) {
                        content
                    }
                    .padding(.top, isCompact ? 18 : 28)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 12)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                    .background(
                        UnevenRoundedRectangle(
                            topLeadingRadius: isCompact ? 0 : 28,
                            topTrailingRadius: isCompact ? 0 : 28,
                            style: .continuous
                        )
                        .fill(Theme.background)
                    )
                    .padding(.top, isCompact ? 0 : -26)
                }
                .frame(minHeight: proxy.size.height + topInset, alignment: .top)
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
            .ignoresSafeArea(.container, edges: .top)
            .background {
                // Emerald behind the status bar and the top overscroll, the
                // page background below, so neither edge shows a seam.
                VStack(spacing: 0) {
                    Theme.primary.frame(height: topInset + 240)
                    Theme.background
                }
                .ignoresSafeArea()
            }
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.25), value: isCompact)
        }
    }
}

/// The emerald band: handles logo, rounded "Trays" wordmark in cream and the
/// gold eyebrow, centred below the status bar.
struct AuthBand: View {
    let style: AuthBandStyle
    let topInset: CGFloat

    var body: some View {
        let isHero = style == .hero
        VStack(spacing: 0) {
            Image("Logo-dark")
                .resizable()
                .scaledToFit()
                .frame(width: isHero ? 112 : 81, height: isHero ? 88 : 64)
                .padding(.top, 8)
                .accessibilityHidden(true)

            VStack(spacing: 0) {
                Text("Trays")
                    .roundedFont(isHero ? 48 : 40, weight: .black, relativeTo: .largeTitle)
                    .tracking(-1)
                    .foregroundStyle(Theme.cream)

                Text("RECIPES WORTH KEEPING")
                    .scaledFont(12, weight: .semibold, relativeTo: .caption)
                    .tracking(2.4)
                    .foregroundStyle(Theme.gold)
                    .padding(.top, 10)
            }
            .padding(.top, 12)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Trays. Recipes worth keeping.")
            .accessibilityAddTraits(.isHeader)
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, 24)
        // Canvas: the band is at least safe area + 204 + 26 (Welcome: safe
        // area + 204 + 70). The bottom 26 is padding the sheet overlaps, so
        // the content area is 204 (Welcome: 248). Minimums only, so larger
        // text grows it.
        .frame(maxWidth: .infinity, minHeight: isHero ? 248 : 204)
        .padding(.top, topInset)
        .padding(.bottom, 26)
        .background(Theme.primary)
    }
}

/// Keyboard up: a 56pt emerald bar with the small logo and wordmark side by
/// side. The navigation back button sits over its leading edge.
struct AuthCompactBar: View {
    let topInset: CGFloat

    var body: some View {
        HStack(spacing: 9) {
            Image("Logo-dark")
                .resizable()
                .scaledToFit()
                .frame(width: 34, height: 27)
                .accessibilityHidden(true)
            Text("Trays")
                .roundedFont(21, weight: .black, relativeTo: .title3)
                .tracking(-0.5)
                .foregroundStyle(Theme.cream)
        }
        .frame(maxWidth: .infinity, minHeight: 56)
        .padding(.top, topInset)
        .background(Theme.primary)
        .accessibilityElement(children: .combine)
    }
}

/// Screen heading and its muted subline (rounded heavy 30 over 15 muted).
struct AuthHeading: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .roundedFont(30, weight: .heavy, relativeTo: .largeTitle)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(subtitle)
                    .scaledFont(15, relativeTo: .subheadline)
                    .foregroundStyle(Theme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// The label above every field: 13.5 semibold body colour. Hidden from
/// VoiceOver because the field below carries the same label.
struct AuthFieldLabel: View {
    let title: LocalizedStringKey

    init(_ title: LocalizedStringKey) {
        self.title = title
    }

    var body: some View {
        Text(title)
            .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
            .foregroundStyle(Theme.text)
            .accessibilityHidden(true)
    }
}

extension View {
    /// The sign-in field box: `surface` fill, 52pt, the shared ring and
    /// amber focus halo, 17pt text, dimmed while a request is in flight.
    func authField(isFocused: Bool, needsAttention: Bool = false, isBusy: Bool = false) -> some View {
        scaledFont(17, relativeTo: .body)
            .frame(minHeight: 50)
            .trayField(
                isFocused: isFocused,
                needsAttention: needsAttention,
                minHeight: 52,
                fill: Theme.surface
            )
            .opacity(isBusy ? 0.55 : 1)
    }
}

/// One message in place, above the button it belongs to: amber-muted fill,
/// amber border, an exclamation symbol and body-colour text. Never red; the
/// symbol and the words carry the meaning. Announced to VoiceOver.
struct AuthCallout: View {
    let message: String
    var systemImage = "exclamationmark.circle"

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Image(systemName: systemImage)
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scaledFont(14.5, relativeTo: .subheadline)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.accentMuted))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Theme.accentBorder, lineWidth: 1)
        )
        .accessibilityElement(children: .combine)
        .onAppear { AccessibilityNotification.Announcement(message).post() }
        .onChange(of: message) { _, newValue in
            AccessibilityNotification.Announcement(newValue).post()
        }
    }
}

/// A labelled switch row, at least 52pt: 16 medium title over an optional
/// 13 muted subline, tinted emerald (the lighter emerald in dark mode).
struct AuthSwitchRow: View {
    let title: LocalizedStringKey
    var subtitle: LocalizedStringKey?
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .scaledFont(16, weight: .medium, relativeTo: .body)
                    .foregroundStyle(Theme.text)
                    .fixedSize(horizontal: false, vertical: true)
                if let subtitle {
                    Text(subtitle)
                        .scaledFont(13, relativeTo: .footnote)
                        .foregroundStyle(Theme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .tint(Theme.authSwitchTint)
        .frame(minHeight: 52)
    }
}

/// The "or" rule between Log in and Sign in with Face ID.
struct AuthOrDivider: View {
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Theme.hairlineStrong).frame(height: 1)
            Text("or")
                .scaledFont(13, relativeTo: .footnote)
                .foregroundStyle(Theme.muted)
            Rectangle().fill(Theme.hairlineStrong).frame(height: 1)
        }
        .accessibilityHidden(true)
    }
}

/// The footer under a form: muted prompt and an emerald (mint in dark) link,
/// 15pt, 44pt hit. Stacks when the larger text sizes no longer fit one line.
struct AuthFooterLink: View {
    let prompt: LocalizedStringKey
    let linkTitle: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 4) { content }
            VStack(spacing: 0) { content }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }

    @ViewBuilder private var content: some View {
        Text(prompt)
            .scaledFont(15, relativeTo: .subheadline)
            .foregroundStyle(Theme.muted)
        Button(action: action) {
            Text(linkTitle)
                .scaledFont(15, weight: .semibold, relativeTo: .subheadline)
                .foregroundStyle(Theme.primaryInk)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// The loading spinner inside the amber call to action.
struct AuthButtonSpinner: View {
    let accessibilityLabel: LocalizedStringKey

    var body: some View {
        ProgressView()
            .tint(Theme.inkOnAccent)
            .accessibilityLabel(accessibilityLabel)
    }
}

extension Text {
    /// The email field's placeholder. Verbatim so the address is not turned
    /// into a link, in the muted placeholder colour.
    static var authEmailPrompt: Text {
        Text(verbatim: "you@example.com").foregroundStyle(Theme.muted)
    }

    /// A field placeholder in the muted placeholder colour (5.4:1 on the
    /// light surface), so every sign-in field matches Log in.
    static func authPrompt(_ key: LocalizedStringKey) -> Text {
        Text(key).foregroundStyle(Theme.muted)
    }
}

extension Theme {
    /// Switch tint on the sign-in screens: emerald in light, the lighter
    /// emerald in dark (3.5:1 on the dark background).
    static let authSwitchTint = Color(light: primary, dark: primaryLight)
}

private struct AuthControlsGallery: View {
    @State private var isOn = true

    var body: some View {
        AuthScreen {
            AuthHeading(title: "Welcome back", subtitle: "Log in to get back to your tray.")
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .leading, spacing: 8) {
                    AuthFieldLabel("Email")
                    TextField("Email", text: .constant(""), prompt: Text(verbatim: "you@example.com"))
                        .authField(isFocused: true)
                }
                AuthSwitchRow(title: "Remember me", subtitle: "Use Face ID next time", isOn: $isOn)
                AuthCallout(message: "Invalid email or password.")
                Button("Log in") {}.buttonStyle(AuthCTAButtonStyle())
                Button("Log in") {}.buttonStyle(AuthCTAButtonStyle()).disabled(true)
                AuthOrDivider()
                Button {} label: { Label("Sign in with Face ID", systemImage: "faceid") }
                    .buttonStyle(AuthOutlineButtonStyle())
            }
            .padding(.top, 24)
            Spacer(minLength: 24)
            AuthFooterLink(prompt: "New here?", linkTitle: "Create an account") {}
        }
    }
}

#Preview("Auth controls · light") {
    AuthControlsGallery().preferredColorScheme(.light)
}

#Preview("Auth controls · dark") {
    AuthControlsGallery().preferredColorScheme(.dark)
}

#Preview("Auth controls · largest text") {
    AuthControlsGallery().dynamicTypeSize(.accessibility5)
}
