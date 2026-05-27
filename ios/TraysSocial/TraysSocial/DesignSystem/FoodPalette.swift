import SwiftUI

/// Color stops for the prototype's gradient food placeholders. Mirrors
/// the `FOOD` dictionary in
/// docs/superpowers/specs/2026-05-27-claude-design-pass-01-prototype.jsx
/// lines 56-67 — three stops per key, used by `Photo` to render a
/// radial gradient that reads as the food without lying about it.
///
/// Pure data, no view code: a future Goal can swap or extend keys
/// without touching `Photo`.
enum FoodPalette {
    enum Key: String, CaseIterable, Hashable {
        case tomato, greens, lemon, cream, honey, cocoa
        case herb, plum, rust, brine, cobalt
    }

    static let defaultKey: Key = .cream

    static func colors(for key: Key) -> [Color] {
        switch key {
        case .tomato: [Color(hex: 0xF3C9A4), Color(hex: 0xD96A3E), Color(hex: 0x7C2B17)]
        case .greens: [Color(hex: 0xCFE0A6), Color(hex: 0x7CA352), Color(hex: 0x2F4622)]
        case .lemon: [Color(hex: 0xF7E9A3), Color(hex: 0xD4A83A), Color(hex: 0x6E541A)]
        case .cream: [Color(hex: 0xF4E8D0), Color(hex: 0xD8B178), Color(hex: 0x7E5A2A)]
        case .honey: [Color(hex: 0xF5D688), Color(hex: 0xC98A2C), Color(hex: 0x5E3B12)]
        case .cocoa: [Color(hex: 0x7A5A3E), Color(hex: 0x3D2A1B), Color(hex: 0x15100A)]
        case .herb: [Color(hex: 0xB8C68A), Color(hex: 0x5C7A3A), Color(hex: 0x243218)]
        case .plum: [Color(hex: 0xC5A4B8), Color(hex: 0x7A4E68), Color(hex: 0x2F1A28)]
        case .rust: [Color(hex: 0xE0A07A), Color(hex: 0xA75A2C), Color(hex: 0x4A210E)]
        case .brine: [Color(hex: 0xBFD3CB), Color(hex: 0x5E8579), Color(hex: 0x1F3833)]
        case .cobalt: [Color(hex: 0xA8B5CC), Color(hex: 0x4A607E), Color(hex: 0x1A2533)]
        }
    }

    /// Lookup by raw string; falls back to `defaultKey` when the string
    /// doesn't match any known food. Used by data layers that store
    /// the palette as a free-form string.
    static func colors(forName name: String) -> [Color] {
        colors(for: Key(rawValue: name) ?? defaultKey)
    }
}
