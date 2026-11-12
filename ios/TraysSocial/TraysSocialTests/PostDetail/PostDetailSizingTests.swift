import SwiftUI
@testable import TraysSocial
import XCTest

/// W247: recipe detail keeps the Recipe artboard's shapes whatever the
/// content: a recipe's photo is 400pt and a legacy photo post's is square,
/// the title stops at three lines at the largest text size, a long cook name
/// does not grow the byline, the meta capsules wrap instead of running off
/// the row, and Cook mode's Back and Next are 60pt high.
@MainActor
final class PostDetailSizingTests: XCTestCase {
    private let screenWidth: CGFloat = 390

    private func size(_ view: some View, width: CGFloat, dynamicType: DynamicTypeSize = .large) -> CGSize {
        let host = UIHostingController(rootView: view.environment(\.dynamicTypeSize, dynamicType))
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude))
    }

    private func hero(_ post: Post) -> some View {
        RecipeHero(post: post, onBack: {}, shareURL: nil)
            .frame(width: screenWidth)
    }

    func test_recipePhotoIs400ptAndALegacyPhotoIsSquare() {
        let recipe = size(hero(PreviewData.recipe()), width: screenWidth).height
        let legacy = size(hero(PreviewData.legacyPhoto), width: screenWidth).height
        XCTAssertEqual(recipe, RecipeHero.recipeHeight, accuracy: 0.5)
        XCTAssertEqual(legacy, screenWidth, accuracy: 0.5)
    }

    func test_longTitleStopsAtThreeLinesAtTheLargestTextSize() {
        func title(_ text: String) -> some View {
            RecipeTitleBlock(kicker: nil, title: text).frame(width: screenWidth - 40)
        }
        let width = screenWidth - 40
        let oneLine = size(title("Dal"), width: width, dynamicType: .accessibility5).height
        let long = size(
            title(String(repeating: "Slow roasted tomato and white bean soup ", count: 6)),
            width: width,
            dynamicType: .accessibility5
        ).height
        XCTAssertGreaterThan(oneLine, 0)
        // Three lines, not one and not the dozen the full title would take.
        XCTAssertGreaterThan(long, oneLine * 2.5)
        XCTAssertLessThan(long, oneLine * 3.5)
    }

    func test_longCookNameKeepsTheBylineToOneLine() {
        func byline(_ name: String) -> some View {
            RecipeBylineRow(username: name, avatarURL: nil, context: "5h", onOpen: {})
                .frame(width: 350)
        }
        // Usernames are at most 30 characters; at a large text size the
        // longest one would wrap if the row let it.
        let width = screenWidth - 40
        let short = size(byline("noor"), width: width, dynamicType: .accessibility3).height
        let long = size(byline("a_very_long_username_for_a_cok"), width: width, dynamicType: .accessibility3).height
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }

    func test_metaCapsulesWrapInsideTheRowAtTheLargestTextSize() {
        let width = screenWidth - 40
        let capsules = RecipeMeta.capsules(for: PreviewData.recipe())
        let row = size(
            RecipeMetaRow(capsules: capsules).frame(width: width, alignment: .leading),
            width: width,
            dynamicType: .accessibility5
        )
        let one = size(RecipeMetaCapsule(capsule: capsules[0]), width: width, dynamicType: .accessibility5)
        XCTAssertLessThanOrEqual(row.width, width + 0.5)
        // Wrapped onto more than one line rather than clipped on one.
        XCTAssertGreaterThan(row.height, one.height * 1.5)
    }

    func test_cookModeBackAndNextAre60ptHigh() {
        let buttons = CookModeNavButtons(canGoBack: true, isLastStep: false, onBack: {}, onNext: {})
            .frame(width: screenWidth - 44)
        XCTAssertEqual(size(buttons, width: screenWidth - 44).height, CookModeNavButtons.minHeight, accuracy: 0.5)
    }
}
