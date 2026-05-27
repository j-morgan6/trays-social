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

    // MARK: - Semantic Colors

    /// Background adapts to light/dark mode
    static let background = Color("Background")

    /// Surface adapts to light/dark mode (cards, elevated surfaces)
    static let surface = Color("Surface")

    /// Primary text adapts to light/dark mode
    static let text = Color("Text")

    /// Secondary text — subdued
    static let textSecondary = Color(hex: 0x757575)

    /// Subtle borders and dividers — adapts to light/dark
    static let border = Color("Surface")

    /// Subtle background for inputs, chips, cards — adapts to light/dark
    static let inputBackground = Color("Surface")

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

    // Overlays
    //
    // scrimGradient is a LinearGradient (NOT a Color). Apply with .overlay(Theme.scrimGradient)
    // to darken the bottom of photo cards for title legibility — do not pass it to
    // .foregroundStyle().
    static let scrimGradient = LinearGradient(
        stops: [
            .init(color: Color.clear, location: 0.3),
            .init(color: Color.black.opacity(0.55), location: 1.0)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
    static let modalScrimLight = Color(red: 250.0 / 255.0, green: 250.0 / 255.0, blue: 246.0 / 255.0, opacity: 0.85)
    static let modalScrimDark = Color(red: 22.0 / 255.0, green: 22.0 / 255.0, blue: 20.0 / 255.0, opacity: 0.78)
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
}

// MARK: - Editorial Typography

//
// Instrument Serif (Regular + Italic) is bundled under
// Resources/Fonts/ and registered via UIAppFonts in Info.plist. These
// helpers mirror the web app's `.font-serif-editorial` utility (see
// assets/css/app.css) so type usage stays consistent across platforms.
//
// Editorial sizes (matching the web type scale):
//   h1 40 / h2 32 / h3 28 / h4 24 / h5 20 / h6 18
//
// Use `.serif(size:)` for recipe titles, wordmark, section headers,
// and quiet emphasis. UI text continues to use SwiftUI system fonts.

extension Font {
    /// Instrument Serif Regular at an arbitrary size.
    static func serif(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Regular", size: size)
    }

    /// Instrument Serif Italic at an arbitrary size.
    static func serifItalic(_ size: CGFloat) -> Font {
        .custom("InstrumentSerif-Italic", size: size)
    }

    // MARK: Editorial Scale (matches web h1–h6)

    static let serifH1 = Font.custom("InstrumentSerif-Regular", size: 40)
    static let serifH2 = Font.custom("InstrumentSerif-Regular", size: 32)
    static let serifH3 = Font.custom("InstrumentSerif-Regular", size: 28)
    static let serifH4 = Font.custom("InstrumentSerif-Regular", size: 24)
    static let serifH5 = Font.custom("InstrumentSerif-Regular", size: 20)
    static let serifH6 = Font.custom("InstrumentSerif-Regular", size: 18)

    /// Oversized hero display — recipe titles on a detail screen.
    static let serifDisplay = Font.custom("InstrumentSerif-Regular", size: 44)
}
