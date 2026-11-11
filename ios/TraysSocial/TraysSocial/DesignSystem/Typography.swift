import SwiftUI

/// W239: the redesign's type. Headings and recipe titles use the rounded
/// system design (SF Pro Rounded); body, bylines and controls stay in the
/// default design. Sizes come from the Components artboard and scale with
/// Dynamic Type through `@ScaledMetric`, which text styles cannot do at
/// these exact sizes.
struct ScaledFont: ViewModifier {
    @ScaledMetric private var size: CGFloat
    private let weight: Font.Weight
    private let design: Font.Design

    init(size: CGFloat, weight: Font.Weight, design: Font.Design, relativeTo textStyle: Font.TextStyle) {
        _size = ScaledMetric(wrappedValue: size, relativeTo: textStyle)
        self.weight = weight
        self.design = design
    }

    func body(content: Content) -> some View {
        content.font(.system(size: size, weight: weight, design: design))
    }
}

/// Named rounded heading sizes from the canvas type table.
enum RoundedHeading {
    case pageTitle
    case emptyHeadline
    case section
    case endHeadline
    case cardTitle

    var size: CGFloat {
        switch self {
        case .pageTitle: 34
        case .emptyHeadline: 23
        case .section: 20
        case .endHeadline: 17
        case .cardTitle: 15
        }
    }

    var weight: Font.Weight {
        switch self {
        case .pageTitle, .emptyHeadline: .heavy
        case .section, .endHeadline, .cardTitle: .bold
        }
    }

    var textStyle: Font.TextStyle {
        switch self {
        case .pageTitle: .largeTitle
        case .emptyHeadline: .title2
        case .section: .title3
        case .endHeadline: .headline
        case .cardTitle: .subheadline
        }
    }
}

extension View {
    /// System font at a fixed canvas size that still scales with Dynamic Type.
    func scaledFont(
        _ size: CGFloat,
        weight: Font.Weight = .regular,
        design: Font.Design = .default,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        modifier(ScaledFont(size: size, weight: weight, design: design, relativeTo: textStyle))
    }

    /// Rounded heading font at an arbitrary size.
    func roundedFont(
        _ size: CGFloat,
        weight: Font.Weight = .bold,
        relativeTo textStyle: Font.TextStyle = .body
    ) -> some View {
        scaledFont(size, weight: weight, design: .rounded, relativeTo: textStyle)
    }

    /// Rounded heading font for one of the canvas heading roles.
    func roundedFont(_ heading: RoundedHeading) -> some View {
        scaledFont(heading.size, weight: heading.weight, design: .rounded, relativeTo: heading.textStyle)
    }
}
