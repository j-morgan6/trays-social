import SwiftUI

struct LegalAcceptanceFooter: View {
    var body: some View {
        Text(makeAttributed())
            .font(.footnote)
            .multilineTextAlignment(.center)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 24)
            .padding(.top, 8)
    }

    private func makeAttributed() -> AttributedString {
        var s = AttributedString("By creating an account, you agree to our Terms and Privacy Policy.")

        // D69: URLs are built from the current build's API base so a Debug
        // install opens the review env's legal pages and a Release install
        // opens prod's — matching the strategy D68 applied to the Settings
        // legal sheets in ProfileView. Previously both URLs were hardcoded
        // to https://trays.app/<path>, leaving review-env testers unable to
        // preview legal copy changes from the auth screen.
        if let termsRange = s.range(of: "Terms") {
            s[termsRange].link = URL(string: Configuration.apiBaseURL + "/terms")
            s[termsRange].foregroundColor = .accentColor
            s[termsRange].underlineStyle = .single
        }

        if let privacyRange = s.range(of: "Privacy Policy") {
            s[privacyRange].link = URL(string: Configuration.apiBaseURL + "/privacy")
            s[privacyRange].foregroundColor = .accentColor
            s[privacyRange].underlineStyle = .single
        }

        return s
    }
}
