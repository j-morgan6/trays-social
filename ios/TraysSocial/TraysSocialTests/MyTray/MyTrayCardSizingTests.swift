import SwiftUI
@testable import TraysSocial
import XCTest

/// W245: cards side by side must be the same size (the user's rule). Each test
/// lays two views out at one fixed width and compares their heights, as
/// SearchCardSizingTests does.
@MainActor
final class MyTrayCardSizingTests: XCTestCase {
    private let columnWidth: CGFloat = 170

    private func height(_ view: some View, width: CGFloat) -> CGFloat {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    private func card(kind: RecipeCard.Kind = .recipe, showsAuthor: Bool = true) -> some View {
        RecipeCard(
            title: "Sesame chicken thighs",
            photoURL: nil,
            authorName: "noor",
            context: "5h",
            cookTime: "35 min",
            kind: kind,
            showsAuthor: showsAuthor
        )
        .frame(width: columnWidth)
    }

    func test_legacyPhotoPostCardIsAsTallAsARecipeCard() {
        let recipe = height(card(), width: columnWidth)
        XCTAssertGreaterThan(recipe, 0)
        XCTAssertEqual(height(card(kind: .photoPost), width: columnWidth), recipe, accuracy: 0.5)
    }

    func test_cardWithoutAuthorIsAsTallAsCardWithAuthor() {
        let withAuthor = height(card(), width: columnWidth)
        XCTAssertGreaterThan(withAuthor, 0)
        XCTAssertEqual(height(card(showsAuthor: false), width: columnWidth), withAuthor, accuracy: 0.5)
    }

    func test_longCollectionNameCardIsAsTallAsShortOne() {
        let short = height(
            CollectionShelfCard(collection: PreviewData.collection(1, "Soups", count: 3)),
            width: CollectionShelf.cardWidth
        )
        let long = height(
            CollectionShelfCard(collection: PreviewData.collection(2, "For guests and long Sunday lunches", count: 3)),
            width: CollectionShelf.cardWidth
        )
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }

    func test_longAuthorUsernameKeepsTheCardHeight() {
        func card(author: String) -> some View {
            RecipeCard(title: "Sesame chicken thighs", photoURL: nil, authorName: author, context: "5h")
                .frame(width: columnWidth)
        }
        let short = height(card(author: "noor"), width: columnWidth)
        let long = height(card(author: "a_really_long_username_30chars"), width: columnWidth)
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }

    func test_longUsernameKeepsTheProfileHeaderHeight() {
        func header(_ username: String) -> some View {
            ProfileHeader(user: PreviewData.user(username), isOwnProfile: false, onToggleFollow: {})
        }
        let width: CGFloat = 354
        let short = height(header("noor"), width: width)
        let long = height(header("a_really_long_username_30chars"), width: width)
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }
}
