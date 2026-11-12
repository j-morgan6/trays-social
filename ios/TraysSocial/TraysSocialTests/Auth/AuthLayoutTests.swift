import SwiftUI
@testable import TraysSocial
import XCTest

/// W251: the sign-in screens share one call to action and one callout, so
/// they render the same on Welcome, Log in, Create account, the username
/// sheet and the verify-email gate. The amber button is a 54pt full-width
/// capsule (Login artboard) and keeps that footprint when it is disabled or
/// busy; a long error grows the callout rather than truncating it; and the
/// footer links swap Log in and Create account instead of stacking them.
@MainActor
final class AuthLayoutTests: XCTestCase {
    private let formWidth: CGFloat = 342

    private func size(_ view: some View, width: CGFloat, dynamicType: DynamicTypeSize = .large) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, dynamicType))
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    private func cta(disabled: Bool = false, busy: Bool = false) -> some View {
        Button("Log in") {}
            .buttonStyle(AuthCTAButtonStyle(isBusy: busy))
            .disabled(disabled)
    }

    func test_callToActionIsA54ptFullWidthCapsule() {
        let cta = size(cta(), width: formWidth)
        XCTAssertEqual(cta.height, 54, accuracy: 0.5)
        XCTAssertEqual(cta.width, formWidth, accuracy: 0.5)
    }

    func test_callToActionKeepsItsFootprintWhenDisabledOrBusy() {
        let enabled = size(cta(), width: formWidth)
        let disabled = size(cta(disabled: true), width: formWidth)
        let busy = size(cta(disabled: true, busy: true), width: formWidth)
        XCTAssertEqual(disabled.height, enabled.height, accuracy: 0.5)
        XCTAssertEqual(busy.height, enabled.height, accuracy: 0.5)
        XCTAssertEqual(disabled.width, enabled.width, accuracy: 0.5)
    }

    func test_longErrorGrowsTheCalloutInsteadOfTruncating() {
        let short = size(AuthCallout(message: "Invalid email or password."), width: formWidth).height
        let long = size(
            AuthCallout(message: String(repeating: "Saved credentials are no longer valid. ", count: 4)),
            width: formWidth
        ).height
        XCTAssertGreaterThan(short, 0)
        XCTAssertGreaterThan(long, short * 2)
    }

    func test_footerLinksReplaceThePathRatherThanStackingScreens() {
        XCTAssertEqual(WelcomeView.path(showing: .register), [.register])
        XCTAssertEqual(WelcomeView.path(showing: .login), [.login])
    }
}
