import SwiftUI

/// The three features Trays Plus unlocks in v1.
///
/// EXHAUSTIVE BY DESIGN. Do not add a case for anything that is free today —
/// `PlusGate` exists to gate the three NEW features and nothing else. Gating a
/// currently-free action would break the product's north star (and W176's
/// acceptance criteria) outright.
///
/// Recipe scaling and offline access are deliberately absent: they are in the
/// monetization strategy doc but deferred to W164/W165, so nothing in the app
/// may advertise or gate them yet.
enum PlusFeature: Equatable, Sendable, CaseIterable {
    case collections
    case mealPlanner
    case groceryList

    /// The contextual line shown at the top of the paywall, so the sheet answers
    /// "why am I seeing this?" instead of appearing out of nowhere.
    var paywallContext: String {
        switch self {
        case .collections:
            String(localized: "Collections are part of Trays Plus.")
        case .mealPlanner:
            String(localized: "The meal planner is part of Trays Plus.")
        case .groceryList:
            String(localized: "The grocery list is part of Trays Plus.")
        }
    }
}

/// What a gate tap does. Extracted from the `Button` body so the single most
/// product-critical decision in this feature is assertable without a
/// view-testing dependency — the project has neither ViewInspector nor an
/// XCUITest target, so a decision left inline in `body` is covered by nothing.
enum PlusGateOutcome: Equatable {
    case run
    case presentPaywall

    /// Entitlement is server truth (`AppState.isPlus`, sourced from `/auth/me`).
    /// There is deliberately no local override.
    static func decide(isPlus: Bool) -> PlusGateOutcome {
        isPlus ? .run : .presentPaywall
    }
}

/// Moment-of-need gate. Renders a real `Button`; runs `action` immediately when
/// the user is entitled, otherwise presents the paywall in context.
///
/// Adoption is a single expression with no state at the call site, which is the
/// point — a gate that needed a `@State` flag and a manual branch would
/// eventually be adopted half-way:
///
/// ```swift
/// PlusGate(.collections) {
///     path.append(.collections)
/// } label: {
///     Label("Collections", systemImage: "square.stack")
/// }
/// ```
///
/// Because it renders a `Button`, `.buttonStyle`, `.disabled` and List row
/// behaviour all pass through unchanged.
struct PlusGate<Content: View>: View {
    @Environment(AppState.self) private var appState
    @State private var showPaywall = false

    private let feature: PlusFeature
    private let action: () -> Void
    private let content: Content

    init(
        _ feature: PlusFeature,
        action: @escaping () -> Void,
        @ViewBuilder label: () -> Content
    ) {
        self.feature = feature
        self.action = action
        content = label()
    }

    var body: some View {
        Button {
            switch PlusGateOutcome.decide(isPlus: appState.isPlus) {
            case .run:
                action()
            case .presentPaywall:
                showPaywall = true
            }
        } label: {
            content
        }
        // Re-runs the gated action when the paywall is dismissed having actually
        // unlocked, so the user lands where they were headed instead of having
        // to tap the same control a second time.
        .plusPaywall(isPresented: $showPaywall, feature: feature, onUnlocked: action)
    }
}

extension View {
    /// Lower-level escape hatch for triggers that cannot be a `PlusGate` button
    /// (a toolbar item, a confirmation-dialog follow-up). `PlusGate` is built on
    /// this, so there is exactly one paywall presentation code path.
    func plusPaywall(
        isPresented: Binding<Bool>,
        feature: PlusFeature?,
        onUnlocked: (() -> Void)? = nil
    ) -> some View {
        modifier(PlusPaywallPresenter(isPresented: isPresented, feature: feature, onUnlocked: onUnlocked))
    }
}

private struct PlusPaywallPresenter: ViewModifier {
    @Environment(AppState.self) private var appState
    @Binding var isPresented: Bool
    let feature: PlusFeature?
    let onUnlocked: (() -> Void)?

    func body(content: Content) -> some View {
        content.sheet(isPresented: $isPresented) {
            if appState.isPlus {
                onUnlocked?()
            }
        } content: {
            PaywallView(context: feature)
        }
    }
}
