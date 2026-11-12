import SwiftUI

// W251: the sign-in screens' buttons (Login artboard): the amber call to
// action, the quiet outline button and the plain text button. The layout
// pieces they sit in are in AuthControls.swift.

/// The amber call to action: full-width 54pt capsule, 17 semibold ink on
/// amber with a soft amber glow. Disabled, it turns quiet (lift fill, strong
/// hairline, muted label, no glow) but still reads as a button. While busy
/// it stays amber so the spinner sits on the colour the user tapped.
struct AuthCTAButtonStyle: ButtonStyle {
    var isBusy = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        AuthCTABody(label: configuration.label, isPressed: configuration.isPressed, isBusy: isBusy)
    }
}

private struct AuthCTABody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let isPressed: Bool
    let isBusy: Bool

    var body: some View {
        let isActive = isEnabled || isBusy
        label
            .scaledFont(17, weight: .semibold, relativeTo: .body)
            .foregroundStyle(isActive ? Theme.inkOnAccent : Theme.muted)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(
                Capsule(style: .continuous)
                    .fill(isActive ? Theme.accent.opacity(isPressed ? 0.85 : 1) : Theme.lift)
            )
            .overlay {
                if !isActive {
                    Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1)
                }
            }
            .shadow(color: isActive ? Theme.accent.opacity(0.35) : .clear, radius: 10, x: 0, y: 8)
            .contentShape(Capsule(style: .continuous))
    }
}

/// The quiet full-width alternative (Sign in with Face ID): surface capsule,
/// strong hairline ring, 17 semibold body colour, 54pt.
struct AuthOutlineButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        AuthOutlineBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct AuthOutlineBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let isPressed: Bool

    var body: some View {
        label
            .scaledFont(17, weight: .semibold, relativeTo: .body)
            .foregroundStyle(Theme.text)
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, minHeight: 54)
            .background(Capsule(style: .continuous).fill(isPressed ? Theme.lift : Theme.surface))
            .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled ? 1 : 0.55)
    }
}

/// A plain full-width text button ("I already have an account"): 17 medium
/// body colour, 48pt high.
struct AuthTextButtonStyle: ButtonStyle {
    var weight: Font.Weight = .medium
    var size: CGFloat = 17
    var color: Color = Theme.text

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        AuthTextBody(label: configuration.label, isPressed: configuration.isPressed, style: self)
    }
}

private struct AuthTextBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let isPressed: Bool
    let style: AuthTextButtonStyle

    var body: some View {
        label
            .scaledFont(style.size, weight: style.weight, relativeTo: .body)
            .foregroundStyle(style.color)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
            .opacity(isPressed ? 0.6 : (isEnabled ? 1 : 0.55))
    }
}
