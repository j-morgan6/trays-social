@testable import TraysSocial
import XCTest

@MainActor
final class TraySectionsTests: XCTestCase {
    private func post(id: Int, userId: Int, type: String = "recipe") -> Post {
        Post(
            id: id, type: type, caption: nil, cookingTimeMinutes: nil, servings: nil,
            likeCount: 0, commentCount: 0, likedByCurrentUser: false, bookmarkedByCurrentUser: nil,
            insertedAt: Date(timeIntervalSince1970: 0),
            user: PostUser(id: userId, username: "u\(userId)", profilePhotoUrl: nil),
            photos: [], ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }

    func test_recipeFirstSplitsByOwnership() {
        // Post 3 is the viewer's own legacy photo post: it belongs in My recipes.
        let posts = [post(id: 1, userId: 7), post(id: 2, userId: 8), post(id: 3, userId: 7, type: "post")]
        let sections = TraySections.make(posts: posts, currentUserId: 7, recipeFirst: true)
        XCTAssertEqual(sections.map(\.title), [String(localized: "My recipes"), String(localized: "Saved")])
        XCTAssertEqual(sections[0].posts.map(\.id), [1, 3])
        XCTAssertEqual(sections[1].posts.map(\.id), [2])
    }

    func test_classicSplitsByType() {
        let posts = [post(id: 1, userId: 7), post(id: 2, userId: 8, type: "post"), post(id: 3, userId: 8)]
        let sections = TraySections.make(posts: posts, currentUserId: 7, recipeFirst: false)
        XCTAssertEqual(sections.map(\.title), [String(localized: "Recipes"), String(localized: "Saved posts")])
        XCTAssertEqual(sections[0].posts.map(\.id), [1, 3])
        XCTAssertEqual(sections[1].posts.map(\.id), [2])
    }

    func test_emptySectionsAreDropped() {
        let sections = TraySections.make(posts: [post(id: 1, userId: 8)], currentUserId: 7, recipeFirst: true)
        XCTAssertEqual(sections.map(\.title), [String(localized: "Saved")])
    }

    func test_bothEmptyReturnsNoSections() {
        XCTAssertEqual(TraySections.make(posts: [], currentUserId: 7, recipeFirst: true), [])
        XCTAssertEqual(TraySections.make(posts: [], currentUserId: 7, recipeFirst: false), [])
    }

    func test_recipeFirstWithNilUserPutsAllInSaved() {
        let posts = [post(id: 1, userId: 7), post(id: 2, userId: 8, type: "post")]
        let sections = TraySections.make(posts: posts, currentUserId: nil, recipeFirst: true)
        XCTAssertEqual(sections.map(\.title), [String(localized: "Saved")])
        XCTAssertEqual(sections[0].posts.map(\.id), [1, 2])
    }

    func test_photoBadgeOnlyForNonRecipesUnderFlag() {
        let photo = post(id: 1, userId: 7, type: "post")
        let recipe = post(id: 2, userId: 7)
        XCTAssertEqual(TraySections.photoBadge(for: photo, recipeFirst: true), String(localized: "Photo"))
        XCTAssertNil(TraySections.photoBadge(for: recipe, recipeFirst: true))
        XCTAssertNil(TraySections.photoBadge(for: photo, recipeFirst: false))
        XCTAssertNil(TraySections.photoBadge(for: recipe, recipeFirst: false))
    }

    func test_createOffersRecipesOnlyWhenRecipeFirst() {
        XCTAssertEqual(CreatePostViewModel.PostType.available(recipeFirst: true), [.recipe])
        XCTAssertEqual(CreatePostViewModel.PostType.available(recipeFirst: false), [.recipe, .post])
    }
}
