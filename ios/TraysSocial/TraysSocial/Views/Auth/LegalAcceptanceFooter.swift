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

        if let termsRange = s.range(of: "Terms") {
            s[termsRange].link = URL(string: "https://trays.app/terms")
            s[termsRange].foregroundColor = .accentColor
            s[termsRange].underlineStyle = .single
        }

        if let privacyRange = s.range(of: "Privacy Policy") {
            s[privacyRange].link = URL(string: "https://trays.app/privacy")
            s[privacyRange].foregroundColor = .accentColor
            s[privacyRange].underlineStyle = .single
        }

        return s
    }
}
