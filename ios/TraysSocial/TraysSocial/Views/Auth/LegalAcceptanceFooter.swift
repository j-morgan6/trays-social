import SwiftUI

/// The Terms and Privacy line under the sign-up buttons. W251: 12.5 muted,
/// centred, with the two links underlined in the body colour (Login
/// artboard). Callers set the spacing around it.
struct LegalAcceptanceFooter: View {
    var body: some View {
        Text(makeAttributed())
            .scaledFont(12.5, relativeTo: .caption)
            .lineSpacing(2)
            .multilineTextAlignment(.center)
            .foregroundStyle(Theme.muted)
            .tint(Theme.text)
            .frame(maxWidth: .infinity)
    }

    private func makeAttributed() -> AttributedString {
        // The link substrings are localized separately and searched for inside
        // the localized sentence, so translations must spell "Terms" and
        // "Privacy Policy" the same way in the full sentence and in their own
        // catalog entries (otherwise the link range won't be found and the
        // words simply render as plain text).
        let termsWord = String(localized: "Terms")
        let privacyWord = String(localized: "Privacy Policy")
        var s = AttributedString(String(localized: "By creating an account, you agree to our Terms and Privacy Policy."))

        // D69: URLs are built from the current build's API base so a Debug
        // install opens the review env's legal pages and a Release install
        // opens prod's — matching the strategy D68 applied to the Settings
        // legal sheets in ProfileView. Previously both URLs were hardcoded
        // to https://trays.app/<path>, leaving review-env testers unable to
        // preview legal copy changes from the auth screen.
        if let termsRange = s.range(of: termsWord) {
            s[termsRange].link = URL(string: Configuration.apiBaseURL + "/terms")
            s[termsRange].foregroundColor = Theme.text
            s[termsRange].underlineStyle = .single
        }

        if let privacyRange = s.range(of: privacyWord) {
            s[privacyRange].link = URL(string: Configuration.apiBaseURL + "/privacy")
            s[privacyRange].foregroundColor = Theme.text
            s[privacyRange].underlineStyle = .single
        }

        return s
    }
}
