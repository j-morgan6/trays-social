import SwiftUI
@testable import TraysSocial
import XCTest

/// W243: cards in a Search row must be the same size (the user's request).
/// Each test lays two views out at one fixed column width and compares their
/// heights, so a byline, title or name that grows a card shows up here.
@MainActor
final class SearchCardSizingTests: XCTestCase {
    private let columnWidth: CGFloat = 170
    /// Narrow enough that an untruncated 30-character username would wrap
    /// past the cooks row's 60pt minimum height. At full width the name fits
    /// whole, and a two-line wrap still sits inside that minimum, so a wider
    /// row would test nothing.
    private let rowWidth: CGFloat = 170

    private func height(_ view: some View, width: CGFloat) -> CGFloat {
        let host = UIHostingController(rootView: view)
        return host.sizeThatFits(in: CGSize(width: width, height: .greatestFiniteMagnitude)).height
    }

    private func recipeCard(title: String) -> some View {
        RecipeCard(title: title, photoURL: nil, authorName: "noor", cookTime: "25 min")
            .frame(width: columnWidth)
    }

    private static func user(_ username: String) -> User {
        User(
            id: 1,
            username: username,
            email: nil,
            bio: nil,
            profilePhotoUrl: nil,
            insertedAt: nil,
            confirmedAt: nil,
            postCount: nil,
            followerCount: nil,
            followingCount: nil,
            followedByCurrentUser: nil,
            isAdmin: nil,
            isSubscriber: nil
        )
    }

    func test_sponsoredCardIsAsTallAsARecipeCard() {
        let sponsored = SponsoredRecipeCard(slot: AdSlot(slot: 0, placement: "find")).frame(width: columnWidth)
        let recipe = height(recipeCard(title: "Peanut noodles"), width: columnWidth)
        XCTAssertGreaterThan(recipe, 0)
        XCTAssertEqual(height(sponsored, width: columnWidth), recipe, accuracy: 0.5)
    }

    func test_longTitleCardIsAsTallAsShortTitleCard() {
        let short = height(recipeCard(title: "Soup"), width: columnWidth)
        let long = height(
            recipeCard(title: "Slow-roasted tomato and white bean soup with crispy garlic breadcrumbs"),
            width: columnWidth
        )
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }

    func test_longUsernameCookRowIsAsTallAsShortOne() {
        let short = height(SearchCooksPanel(users: [Self.user("lucia")]), width: rowWidth)
        let long = height(SearchCooksPanel(users: [Self.user("averyverylongusername_thirty00")]), width: rowWidth)
        XCTAssertGreaterThan(short, 0)
        XCTAssertEqual(long, short, accuracy: 0.5)
    }
}
