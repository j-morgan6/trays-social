import SwiftUI

// W239: the redesign's buttons (Components artboard, "Buttons"). Every
// style is at least 44pt high and dims to 55% when disabled.

/// Emerald capsule with white (light) or cream (dark) text, 50pt high.
struct PrimaryButtonStyle: ButtonStyle {
    var fillsWidth = false

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        TrayButtonBody(
            label: configuration.label,
            fill: configuration.isPressed ? Theme.primaryLight : Theme.primary,
            foreground: Theme.onPrimary,
            ring: nil,
            minHeight: 50,
            fillsWidth: fillsWidth
        )
    }
}

/// Surface capsule with a strong hairline ring: the quiet second action.
struct SecondaryButtonStyle: ButtonStyle {
    var fillsWidth = false
    /// W247: Cook mode's Back and Next are 60pt high (Recipe artboard).
    var minHeight: CGFloat = 50

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        TrayButtonBody(
            label: configuration.label,
            fill: configuration.isPressed ? Theme.lift : Theme.surface,
            foreground: Theme.text,
            ring: Theme.hairlineStrong,
            minHeight: minHeight,
            fillsWidth: fillsWidth
        )
    }
}

/// Amber capsule with ink-on-accent text: Create and the Plus call to action.
struct AccentButtonStyle: ButtonStyle {
    var fillsWidth = false
    /// W247: Cook mode's Back and Next are 60pt high (Recipe artboard).
    var minHeight: CGFloat = 50
    /// W249: the editor's Post button stays full amber with a spinner while
    /// posting (Create artboard), though it is disabled.
    var dimsWhenDisabled = true

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        TrayButtonBody(
            label: configuration.label,
            fill: Theme.accent.opacity(configuration.isPressed ? 0.85 : 1),
            foreground: Theme.inkOnAccent,
            ring: nil,
            minHeight: minHeight,
            fillsWidth: fillsWidth,
            dimsWhenDisabled: dimsWhenDisabled
        )
    }
}

/// Follow toggle: emerald when not following, lift when following.
struct FollowButtonStyle: ButtonStyle {
    let isFollowing: Bool
    /// W245: the friend's-tray header uses a full-width, 48pt Follow button.
    var fillsWidth = false
    var minHeight: CGFloat = 44

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        TrayButtonBody(
            label: configuration.label,
            fill: isFollowing ? Theme.lift : (configuration.isPressed ? Theme.primaryLight : Theme.primary),
            foreground: isFollowing ? Theme.text : Theme.onPrimary,
            ring: nil,
            minHeight: minHeight,
            fillsWidth: fillsWidth,
            fontSize: 14,
            minWidth: 100
        )
    }
}

/// Shared capsule body; a View so it can read `isEnabled`.
private struct TrayButtonBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let fill: Color
    let foreground: Color
    let ring: Color?
    let minHeight: CGFloat
    let fillsWidth: Bool
    var fontSize: CGFloat = 15.5
    var minWidth: CGFloat?
    var dimsWhenDisabled = true

    var body: some View {
        label
            .scaledFont(fontSize, weight: .semibold, relativeTo: .body)
            .foregroundStyle(foreground)
            .padding(.horizontal, 22)
            .frame(minWidth: minWidth, maxWidth: fillsWidth ? .infinity : nil, minHeight: minHeight)
            .background(Capsule(style: .continuous).fill(fill))
            .overlay {
                if let ring {
                    Capsule(style: .continuous).strokeBorder(ring, lineWidth: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
            .opacity(isEnabled || !dimsWhenDisabled ? 1 : 0.55)
    }
}

extension ButtonStyle where Self == PrimaryButtonStyle {
    static var trayPrimary: Self {
        .init()
    }
}

extension ButtonStyle where Self == SecondaryButtonStyle {
    static var traySecondary: Self {
        .init()
    }
}

extension ButtonStyle where Self == AccentButtonStyle {
    static var trayAccent: Self {
        .init()
    }
}

extension ButtonStyle where Self == FollowButtonStyle {
    static func follow(isFollowing: Bool, fillsWidth: Bool = false, minHeight: CGFloat = 44) -> Self {
        .init(isFollowing: isFollowing, fillsWidth: fillsWidth, minHeight: minHeight)
    }
}

private struct ButtonStylesGallery: View {
    var body: some View {
        VStack(spacing: 14) {
            Button {} label: { Label("Post your first recipe", systemImage: "plus") }
                .buttonStyle(.trayPrimary)
            Button {} label: { Label("Find recipes in Search", systemImage: "magnifyingglass") }
                .buttonStyle(.traySecondary)
            HStack(spacing: 12) {
                Button("Follow") {}.buttonStyle(.follow(isFollowing: false))
                Button("Following") {}.buttonStyle(.follow(isFollowing: true))
            }
            Button("Try Trays Plus") {}.buttonStyle(.trayAccent)
            Button("Disabled") {}.buttonStyle(.trayPrimary).disabled(true)
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("Buttons · light") {
    ButtonStylesGallery().preferredColorScheme(.light)
}

#Preview("Buttons · dark") {
    ButtonStylesGallery().preferredColorScheme(.dark)
}

#Preview("Buttons · largest text") {
    ButtonStylesGallery().dynamicTypeSize(.accessibility5)
}
