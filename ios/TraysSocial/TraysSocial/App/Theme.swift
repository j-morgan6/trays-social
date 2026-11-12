import SwiftUI

enum Theme {
    // MARK: - Modern Kitchen Palette

    /// Emerald Chef — primary actions, main UI elements
    static let primary = Color(hex: 0x1B5E20)

    /// Emerald Light — borders, secondary green elements
    static let primaryLight = Color(hex: 0x2E7D32)

    /// Mint Whisper — supporting elements, subtle highlights
    static let secondary = Color(hex: 0xA5D6A7)

    /// Golden Amber — accent, CTAs, highlights, badges
    static let accent = Color(hex: 0xFFB300)

    /// Cream — wordmark on the emerald hero + the tray illustration fill
    /// (Welcome screen brand surface). Fixed brand color, not adaptive.
    static let cream = Color(hex: 0xF4EFE2)

    /// Gold — eyebrow text on the emerald hero (Welcome screen brand).
    /// Fixed brand color, not adaptive.
    static let gold = Color(hex: 0xFFC65A)

    // MARK: - Semantic Colors

    //
    // W239: background, surface and text resolve from the canvas pairs below
    // instead of the Background/Surface/Text colorsets, which held older values.

    /// Screen background — adapts to light/dark mode
    static let background = Color(light: bgLight, dark: bgDark)

    /// Cards and elevated surfaces — adapts to light/dark mode
    static let surface = Color(light: surfaceLight, dark: surfaceDark)

    /// Primary text — adapts to light/dark mode
    static let text = Color(light: textLight, dark: textDark)

    /// Secondary text — subdued
    static let textSecondary = Color(hex: 0x757575)

    /// Chip and field rings — the canvas border token
    static let border = Color(
        light: borderLight,
        dark: borderDark,
        highContrastLight: Color(hex: 0x1A1A1A, opacity: 0.20),
        highContrastDark: Color(hex: 0xEDEDE7, opacity: 0.24)
    )

    /// Inputs, chips and cards
    static let inputBackground = surface

    // MARK: - Pass 1 Prototype Tokens

    //
    // Values locked to docs/superpowers/specs/2026-05-27-claude-design-pass-01-prototype.jsx
    // (lines 11-38). Theme.primary, Theme.accent, and the legacy semantic colors above stay
    // unchanged — the new tokens below are additive surfaces consumed by the nav shell and
    // downstream screens.

    // Pill chrome
    static let pillBgLight = Color(red: 1.0, green: 1.0, blue: 1.0, opacity: 0.78)
    static let pillBgDark = Color(red: 32.0 / 255.0, green: 32.0 / 255.0, blue: 30.0 / 255.0, opacity: 0.72)
    static let pillBackdropBlurRadius: CGFloat = 20.0

    // Light-mode surfaces
    static let bgLight = Color(hex: 0xFAFAF6)
    static let surfaceLight = Color(hex: 0xFFFFFF)
    static let liftLight = Color(hex: 0xF2EFE6)
    static let textLight = Color(hex: 0x1A1A1A)
    static let mutedLight = Color(hex: 0x6A6A66)
    static let subtleLight = Color(hex: 0x9B9B95)

    // Dark-mode surfaces
    static let bgDark = Color(hex: 0x161614)
    static let surfaceDark = Color(hex: 0x1F1F1D)
    static let liftDark = Color(hex: 0x2A2A27)
    static let textDark = Color(hex: 0xEDEDE7)
    static let mutedDark = Color(hex: 0x9A9A93)
    static let subtleDark = Color(hex: 0x6A6A65)

    // Hairlines + borders
    static let hairLight = Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, opacity: 0.05)
    static let hairDark = Color(red: 237.0 / 255.0, green: 237.0 / 255.0, blue: 231.0 / 255.0, opacity: 0.06)
    static let hairStrongLight = Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, opacity: 0.10)
    static let hairStrongDark = Color(red: 237.0 / 255.0, green: 237.0 / 255.0, blue: 231.0 / 255.0, opacity: 0.12)
    static let borderLight = Color(red: 26.0 / 255.0, green: 26.0 / 255.0, blue: 26.0 / 255.0, opacity: 0.08)
    static let borderDark = Color(red: 237.0 / 255.0, green: 237.0 / 255.0, blue: 231.0 / 255.0, opacity: 0.10)

    // Amber accent family (Theme.accent #FFB300 stays the canonical accent)
    static let accentInkLight = Color(hex: 0xFF8F00)
    static let accentInkDark = Color(hex: 0xFFC246)
    static let accentMuted = Color(red: 255.0 / 255.0, green: 179.0 / 255.0, blue: 0.0 / 255.0, opacity: 0.25)
    static let accentPressed = Color(red: 255.0 / 255.0, green: 179.0 / 255.0, blue: 0.0 / 255.0, opacity: 0.40)
    static let accentBorder = Color(red: 255.0 / 255.0, green: 179.0 / 255.0, blue: 0.0 / 255.0, opacity: 0.32)
    static let inkOnAccent = Color(hex: 0x1A1A1A)

    /// Overlays
    ///
    /// scrimGradient is a LinearGradient (NOT a Color). Apply with .overlay(Theme.scrimGradient)
    /// to darken the bottom of photo cards for title legibility — do not pass it to
    /// .foregroundStyle().
    static let scrimGradient = LinearGradient(
        stops: [
            .init(color: Color.clear, location: 0.3),
            .init(color: Color.black.opacity(0.55), location: 1.0),
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let modalScrimLight = Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 246.0 / 255.0, opacity: 0.85)
    static let modalScrimDark = Color(red: 22.0 / 255.0, green: 22.0 / 255.0, blue: 20.0 / 255.0, opacity: 0.78)

    // MARK: - Adaptive tokens (canvas token map)

    //
    // W239: single tokens that resolve per trait collection, so views no
    // longer need @Environment(\.colorScheme) plus a `(for:)` helper. The
    // `(for:)` helpers below stay until the screen tasks stop using them.

    static let lift = Color(light: liftLight, dark: liftDark)
    static let muted = Color(light: mutedLight, dark: mutedDark)
    static let subtle = Color(light: subtleLight, dark: subtleDark)
    static let hairline = Color(
        light: hairLight,
        dark: hairDark,
        highContrastLight: Color(hex: 0x1A1A1A, opacity: 0.16),
        highContrastDark: Color(hex: 0xEDEDE7, opacity: 0.20)
    )
    static let hairlineStrong = Color(
        light: hairStrongLight,
        dark: hairStrongDark,
        highContrastLight: Color(hex: 0x1A1A1A, opacity: 0.24),
        highContrastDark: Color(hex: 0xEDEDE7, opacity: 0.28)
    )
    /// Floating pill fill (tab bar, bottom bar, time pill); layer over .ultraThinMaterial
    static let pill = Color(light: pillBgLight, dark: pillBgDark)
    /// Secondary (mint) at 35% light / 14% dark: end card, tiles, Ready pill
    static let mintTint = Color(
        light: Color(hex: 0xA5D6A7, opacity: 0.35),
        dark: Color(hex: 0xA5D6A7, opacity: 0.14)
    )
    /// Photo, avatar and empty-block fill: cream in light, lift in dark
    static let creamOrLift = Color(light: cream, dark: liftDark)
    /// W247: Cook mode page: cream in light, the page background in dark
    static let cookBackground = Color(light: cream, dark: bgDark)
    /// Links, See all, Ready pill text: emerald in light, mint in dark
    static let primaryInk = Color(light: primary, dark: secondary)
    /// Text on an emerald fill: white in light, cream in dark
    static let onPrimary = Color(light: Color(hex: 0xFFFFFF), dark: cream)
    /// Soft drop shadow for pills and cards
    static let shadow = Color(light: Color(hex: 0x1A1A1A, opacity: 0.08), dark: Color(hex: 0x000000, opacity: 0.35))

    // MARK: - Adaptive Helpers

    //
    // Components read @Environment(\.colorScheme) and ask Theme for the right per-mode token,
    // so each view doesn't re-implement the light-vs-dark switch inline.

    static func pillBg(for scheme: ColorScheme) -> Color {
        scheme == .dark ? pillBgDark : pillBgLight
    }

    static func hairline(for scheme: ColorScheme) -> Color {
        scheme == .dark ? hairDark : hairLight
    }

    static func muted(for scheme: ColorScheme) -> Color {
        scheme == .dark ? mutedDark : mutedLight
    }

    static func subtle(for scheme: ColorScheme) -> Color {
        scheme == .dark ? subtleDark : subtleLight
    }

    static func accentInk(for scheme: ColorScheme) -> Color {
        scheme == .dark ? accentInkDark : accentInkLight
    }

    static func lift(for scheme: ColorScheme) -> Color {
        scheme == .dark ? liftDark : liftLight
    }
}

// MARK: - Hex Color Initializer

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: opacity
        )
    }

    /// A colour that resolves per trait collection: `dark` in Dark Mode,
    /// `light` otherwise, and the optional high-contrast variants when
    /// Increase Contrast is on.
    init(light: Color, dark: Color, highContrastLight: Color? = nil, highContrastDark: Color? = nil) {
        let lightColor = UIColor(light)
        let darkColor = UIColor(dark)
        let contrastLight = highContrastLight.map { UIColor($0) } ?? lightColor
        let contrastDark = highContrastDark.map { UIColor($0) } ?? darkColor
        self.init(uiColor: UIColor { traits in
            let highContrast = traits.accessibilityContrast == .high
            if traits.userInterfaceStyle == .dark {
                return highContrast ? contrastDark : darkColor
            }
            return highContrast ? contrastLight : lightColor
        })
    }
}
