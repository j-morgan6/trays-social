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
