import SwiftUI

/// W239: closes the new-from-follows row so it never scrolls forever
/// (Components artboard, "End card"). Mint tint fill, radius 21.
struct EndCard: View {
    let title: String
    let message: String
    var systemImage: String = "checkmark"

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(Theme.primaryInk)
                .accessibilityHidden(true)
            Text(title)
                .roundedFont(.endHeadline)
                .foregroundStyle(Theme.text)
            Text(message)
                .scaledFont(13.5, relativeTo: .footnote)
                .foregroundStyle(Theme.muted)
        }
        .padding(.vertical, 20)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Theme.mintTint))
        .accessibilityElement(children: .combine)
    }
}

#Preview("EndCard · light") {
    EndCard(title: "You're caught up", message: "That's everything from the last 7 days. Time to cook.")
        .frame(width: 176, height: 260)
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.light)
}

#Preview("EndCard · dark") {
    EndCard(title: "You're caught up", message: "That's everything from the last 7 days. Time to cook.")
        .frame(width: 176, height: 260)
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

#Preview("EndCard · largest text") {
    EndCard(title: "You're caught up", message: "That's everything from the last 7 days. Time to cook.")
        .frame(width: 176, height: 260)
        .padding()
        .background(Theme.background)
        .dynamicTypeSize(.accessibility5)
}
