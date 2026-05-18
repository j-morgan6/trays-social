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
