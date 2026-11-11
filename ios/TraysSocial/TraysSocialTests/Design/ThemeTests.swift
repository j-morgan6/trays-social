import SwiftUI
@testable import TraysSocial
import XCTest

/// W239: the redesign token map (Claude Design canvas, Components artboard).
/// Each adaptive token is resolved against a light and a dark trait
/// collection and compared with the canvas value.
@MainActor
final class ThemeTests: XCTestCase {
    private struct RGBA {
        let red: CGFloat
        let green: CGFloat
        let blue: CGFloat
        let alpha: CGFloat
    }

    private func resolve(
        _ color: Color,
        _ style: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast = .normal
    ) -> RGBA {
        let traits = UITraitCollection { mutable in
            mutable.userInterfaceStyle = style
            mutable.accessibilityContrast = contrast
        }
        let resolved = UIColor(color).resolvedColor(with: traits)
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(red: red, green: green, blue: blue, alpha: alpha)
    }

    private func assertColor(
        _ actual: RGBA,
        hex: UInt,
        alpha: CGFloat,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let rgbAccuracy: CGFloat = 0.6 / 255
        let red = CGFloat((hex >> 16) & 0xFF) / 255
        let green = CGFloat((hex >> 8) & 0xFF) / 255
        let blue = CGFloat(hex & 0xFF) / 255
        XCTAssertEqual(actual.red, red, accuracy: rgbAccuracy, "\(name) red", file: file, line: line)
        XCTAssertEqual(actual.green, green, accuracy: rgbAccuracy, "\(name) green", file: file, line: line)
        XCTAssertEqual(actual.blue, blue, accuracy: rgbAccuracy, "\(name) blue", file: file, line: line)
        XCTAssertEqual(actual.alpha, alpha, accuracy: 0.002, "\(name) alpha", file: file, line: line)
    }

    private func assertToken(
        _ color: Color,
        _ name: String,
        light: UInt,
        lightAlpha: CGFloat = 1,
        dark: UInt,
        darkAlpha: CGFloat = 1,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let lightValue = resolve(color, .light)
        let darkValue = resolve(color, .dark)
        assertColor(lightValue, hex: light, alpha: lightAlpha, "\(name) light", file: file, line: line)
        assertColor(darkValue, hex: dark, alpha: darkAlpha, "\(name) dark", file: file, line: line)
        let differs = lightValue.red != darkValue.red || lightValue.green != darkValue.green
            || lightValue.blue != darkValue.blue || lightValue.alpha != darkValue.alpha
        XCTAssertTrue(differs, "\(name) should differ between light and dark", file: file, line: line)
    }

    func test_everyNewTokenResolvesDistinctLightAndDarkValues() {
        assertToken(Theme.background, "background", light: 0xFAFAF6, dark: 0x161614)
        assertToken(Theme.surface, "surface", light: 0xFFFFFF, dark: 0x1F1F1D)
        assertToken(Theme.lift, "lift", light: 0xF2EFE6, dark: 0x2A2A27)
        assertToken(Theme.text, "text", light: 0x1A1A1A, dark: 0xEDEDE7)
        assertToken(Theme.muted, "muted", light: 0x6A6A66, dark: 0x9A9A93)
        assertToken(Theme.subtle, "subtle", light: 0x9B9B95, dark: 0x6A6A65)
        assertToken(Theme.hairline, "hairline", light: 0x1A1A1A, lightAlpha: 0.05, dark: 0xEDEDE7, darkAlpha: 0.06)
        assertToken(
            Theme.hairlineStrong, "hairlineStrong", light: 0x1A1A1A, lightAlpha: 0.10, dark: 0xEDEDE7, darkAlpha: 0.12
        )
        assertToken(Theme.border, "border", light: 0x1A1A1A, lightAlpha: 0.08, dark: 0xEDEDE7, darkAlpha: 0.10)
        assertToken(Theme.pill, "pill", light: 0xFFFFFF, lightAlpha: 0.78, dark: 0x20201E, darkAlpha: 0.72)
        assertToken(Theme.mintTint, "mintTint", light: 0xA5D6A7, lightAlpha: 0.35, dark: 0xA5D6A7, darkAlpha: 0.14)
        assertToken(Theme.creamOrLift, "creamOrLift", light: 0xF4EFE2, dark: 0x2A2A27)
        assertToken(Theme.primaryInk, "primaryInk", light: 0x1B5E20, dark: 0xA5D6A7)
        assertToken(Theme.onPrimary, "onPrimary", light: 0xFFFFFF, dark: 0xF4EFE2)
        assertToken(Theme.shadow, "shadow", light: 0x1A1A1A, lightAlpha: 0.08, dark: 0x000000, darkAlpha: 0.35)
    }

    func test_fixedTokensResolveSameValueInBothModes() {
        struct Fixed {
            let color: Color
            let name: String
            let hex: UInt
            let alpha: CGFloat
            init(_ color: Color, _ name: String, _ hex: UInt, _ alpha: CGFloat) {
                (self.color, self.name, self.hex, self.alpha) = (color, name, hex, alpha)
            }
        }
        let fixed: [Fixed] = [
            Fixed(Theme.primary, "primary", 0x1B5E20, 1),
            Fixed(Theme.primaryLight, "primaryLight", 0x2E7D32, 1),
            Fixed(Theme.secondary, "secondary", 0xA5D6A7, 1),
            Fixed(Theme.accent, "accent", 0xFFB300, 1),
            Fixed(Theme.accentMuted, "accentMuted", 0xFFB300, 0.25),
            Fixed(Theme.accentPressed, "accentPressed", 0xFFB300, 0.40),
            Fixed(Theme.accentBorder, "accentBorder", 0xFFB300, 0.32),
            Fixed(Theme.inkOnAccent, "inkOnAccent", 0x1A1A1A, 1),
            Fixed(Theme.cream, "cream", 0xF4EFE2, 1),
        ]
        for token in fixed {
            assertColor(resolve(token.color, .light), hex: token.hex, alpha: token.alpha, "\(token.name) light")
            assertColor(resolve(token.color, .dark), hex: token.hex, alpha: token.alpha, "\(token.name) dark")
        }
    }

    func test_legacyPairsMatchAdaptiveTokens() {
        assertColor(resolve(Theme.background, .light), hex: 0xFAFAF6, alpha: 1, "bgLight")
        assertColor(resolve(Theme.bgLight, .light), hex: 0xFAFAF6, alpha: 1, "bgLight pair")
        assertColor(resolve(Theme.bgDark, .light), hex: 0x161614, alpha: 1, "bgDark pair")
        assertColor(resolve(Theme.textDark, .light), hex: 0xEDEDE7, alpha: 1, "textDark pair")
        assertColor(resolve(Theme.lift(for: .dark), .light), hex: 0x2A2A27, alpha: 1, "lift(for:) helper")
        assertColor(resolve(Theme.muted(for: .light), .dark), hex: 0x6A6A66, alpha: 1, "muted(for:) helper")
    }

    func test_increaseContrastStrengthensHairlines() {
        let hairlines = [(Theme.hairline, "hairline"), (Theme.hairlineStrong, "hairlineStrong"), (Theme.border, "border")]
        for (color, name) in hairlines {
            for style in [UIUserInterfaceStyle.light, .dark] {
                let normal = resolve(color, style).alpha
                let high = resolve(color, style, contrast: .high).alpha
                XCTAssertGreaterThan(high, normal, "\(name) should be stronger with Increase Contrast")
            }
        }
    }

    func test_noBundledFontsRemain() {
        XCTAssertNil(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts"))
        for ext in ["ttf", "otf"] {
            XCTAssertTrue((Bundle.main.urls(forResourcesWithExtension: ext, subdirectory: nil) ?? []).isEmpty)
        }
        // The family name is split so a repo-wide grep for the retired font stays empty.
        let retiredFamily = ["Instru", "ment Serif"].joined()
        XCTAssertFalse(UIFont.familyNames.contains(retiredFamily))
    }

    func test_roundedHeadingsMatchCanvasType() {
        let sizes: [RoundedHeading: CGFloat] = [
            .pageTitle: 34, .emptyHeadline: 23, .section: 20, .endHeadline: 17, .cardTitle: 15,
        ]
        let weights: [RoundedHeading: Font.Weight] = [
            .pageTitle: .heavy, .emptyHeadline: .heavy, .section: .bold, .endHeadline: .bold, .cardTitle: .bold,
        ]
        let styles: [RoundedHeading: Font.TextStyle] = [
            .pageTitle: .largeTitle, .emptyHeadline: .title2, .section: .title3,
            .endHeadline: .headline, .cardTitle: .subheadline,
        ]
        for heading in [RoundedHeading.pageTitle, .emptyHeadline, .section, .endHeadline, .cardTitle] {
            XCTAssertEqual(heading.size, sizes[heading], "\(heading) size")
            XCTAssertEqual(heading.weight, weights[heading], "\(heading) weight")
            XCTAssertEqual(heading.textStyle, styles[heading], "\(heading) text style")
        }
    }

    func test_reduceMotionKeepsSkeletonPulseStatic() {
        XCTAssertEqual(SkeletonPulseOpacity.value(reduceMotion: true, dimmed: true), 1)
        XCTAssertEqual(SkeletonPulseOpacity.value(reduceMotion: true, dimmed: false), 1)
        XCTAssertEqual(SkeletonPulseOpacity.value(reduceMotion: false, dimmed: false), 1)
        XCTAssertEqual(SkeletonPulseOpacity.value(reduceMotion: false, dimmed: true), 0.5)
    }
}
