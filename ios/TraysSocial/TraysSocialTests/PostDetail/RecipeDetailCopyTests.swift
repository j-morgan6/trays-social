@testable import TraysSocial
import XCTest

/// W247: the recipe title, cook's note, ingredient ticks, meta row and
/// load-failure copy on recipe detail.
final class RecipeDetailCopyTests: XCTestCase {
    // MARK: - RecipeTitle

    func test_titleIsTheFirstSentence() {
        XCTAssertEqual(RecipeTitle.from(caption: "Sesame chicken. Crisp skin.", fallback: "X"), "Sesame chicken")
        XCTAssertEqual(RecipeTitle.from(caption: "Weeknight dal\nRoast it hot.", fallback: "X"), "Weeknight dal")
        XCTAssertEqual(RecipeTitle.from(caption: "Wait... it's good", fallback: "X"), "Wait")
    }

    func test_titleWithoutATerminatorIsTheWholeCaption() {
        XCTAssertEqual(RecipeTitle.from(caption: "  Weeknight dal  ", fallback: "X"), "Weeknight dal")
    }

    // D125: the shared title vectors. A sibling web task adopts the same rule
    // and vectors, so a change here needs the matching change there.

    func test_titleKeepsAPeriodAfterAnAbbreviation() {
        XCTAssertEqual(RecipeTitle.from(caption: "Mrs. Smith's pie", fallback: "X"), "Mrs. Smith's pie")
        XCTAssertEqual(RecipeTitle.from(caption: "mrs. smith's pie", fallback: "X"), "mrs. smith's pie")
        XCTAssertEqual(RecipeTitle.from(caption: "St. Louis ribs!", fallback: "X"), "St. Louis ribs")
        XCTAssertEqual(RecipeTitle.from(caption: "J. Kenji's eggs", fallback: "X"), "J. Kenji's eggs")
        XCTAssertEqual(RecipeTitle.from(caption: "Dr.", fallback: "X"), "Dr")
    }

    func test_titleEndsAtTheSentenceAfterAnAbbreviation() {
        XCTAssertEqual(
            RecipeTitle.from(caption: "Mrs. Smith's pie. Flaky crust.", fallback: "X"),
            "Mrs. Smith's pie"
        )
    }

    func test_aPeriodInsideANumberNeverEndsTheTitle() {
        XCTAssertEqual(RecipeTitle.from(caption: "1.5 hour brisket", fallback: "X"), "1.5 hour brisket")
        XCTAssertEqual(RecipeTitle.from(caption: "3.5oz steak. Rare.", fallback: "X"), "3.5oz steak")
    }

    func test_emptyOrPunctuationOnlyCaptionsUseTheFallback() {
        XCTAssertEqual(RecipeTitle.from(caption: nil, fallback: "Untitled recipe"), "Untitled recipe")
        XCTAssertEqual(RecipeTitle.from(caption: "   ", fallback: "Untitled recipe"), "Untitled recipe")
        XCTAssertEqual(RecipeTitle.from(caption: "...", fallback: "Untitled recipe"), "Untitled recipe")
        XCTAssertEqual(RecipeTitle.from(caption: "?! .", fallback: "Untitled recipe"), "Untitled recipe")
    }

    @MainActor
    func test_feedAndFindCardsUseRecipeTitle() {
        let post = PreviewData.post(1, "Mrs. Smith's pie. Flaky crust.")
        XCTAssertEqual(FeedCardView.title(for: post), "Mrs. Smith's pie")
        XCTAssertEqual(FindView.gridTitle(for: post), "Mrs. Smith's pie")
        let untitled = PreviewData.post(2, "...")
        XCTAssertEqual(FeedCardView.title(for: untitled), String(localized: "Untitled"))
        XCTAssertEqual(FindView.gridTitle(for: untitled), String(localized: "Untitled"))
    }

    // W266: the other surfaces that show a recipe title. Each view reads its
    // seam, so a surface cannot drift onto its own copy of the rule.

    @MainActor
    func test_trayTileUsesRecipeTitle() {
        let post = PreviewData.post(1, "Mrs. Smith's pie. Flaky crust.")
        XCTAssertEqual(PostRecipeCard.title(for: post), "Mrs. Smith's pie")
    }

    @MainActor
    func test_recipePickerRowUsesRecipeTitle() {
        let post = PreviewData.post(1, "Mrs. Smith's pie. Flaky crust.")
        XCTAssertEqual(RecipePickerSheet.rowTitle(for: post), "Mrs. Smith's pie")
    }

    @MainActor
    func test_recipeDetailTitleUsesRecipeTitle() {
        let post = PreviewData.post(1, "Mrs. Smith's pie. Flaky crust.")
        XCTAssertEqual(RecipeHeadSheet.title(for: post), "Mrs. Smith's pie")
    }

    @MainActor
    func test_shareSubjectUsesRecipeTitle() {
        let post = PreviewData.post(1, "Mrs. Smith's pie. Flaky crust.")
        XCTAssertEqual(RecipeHero.shareTitle(for: post), "Mrs. Smith's pie")
        // The subject leaves the app, so it is the title only, never the caption.
        XCTAssertNotEqual(RecipeHero.shareTitle(for: post), post.caption)
    }

    @MainActor
    func test_surfaceTitlesKeepAbbreviationPeriods() {
        let cases = [
            ("Mrs. Smith's pie. Flaky crust.", "Mrs. Smith's pie"),
            ("St. Louis ribs! Low and slow.", "St. Louis ribs"),
        ]
        for (caption, title) in cases {
            let post = PreviewData.post(1, caption)
            let titles = [
                PostRecipeCard.title(for: post),
                RecipePickerSheet.rowTitle(for: post),
                RecipeHeadSheet.title(for: post),
                RecipeHero.shareTitle(for: post),
            ]
            XCTAssertEqual(titles, Array(repeating: title, count: 4), caption)
        }
    }

    @MainActor
    func test_eachSurfaceKeepsItsOwnFallback() {
        for post in [Self.post(caption: nil), PreviewData.post(2, "...")] {
            XCTAssertEqual(PostRecipeCard.title(for: post), String(localized: "Untitled"))
            XCTAssertEqual(RecipePickerSheet.rowTitle(for: post), String(localized: "Untitled"))
            XCTAssertEqual(RecipeHeadSheet.title(for: post), String(localized: "Untitled recipe"))
            XCTAssertEqual(RecipeHero.shareTitle(for: post), String(localized: "A recipe on Trays"))
        }
    }

    /// PreviewData.post always carries a caption string; this one can be nil.
    private static func post(caption: String?) -> Post {
        Post(
            id: 3, type: "recipe", caption: caption, cookingTimeMinutes: nil, servings: nil,
            likeCount: 0, commentCount: 0, likedByCurrentUser: false, bookmarkedByCurrentUser: nil,
            insertedAt: Date(timeIntervalSince1970: 0),
            user: PostUser(id: 1, username: "ren", profilePhotoUrl: nil),
            photos: [], ingredients: [], cookingSteps: [], tools: [], tags: []
        )
    }

    func test_noteFollowsAnAbbreviatedTitle() {
        XCTAssertEqual(RecipeTitle.note(caption: "Mrs. Smith's pie. Flaky crust."), "Flaky crust")
        XCTAssertEqual(RecipeTitle.note(caption: "Mrs. Smith's pie"), "")
        XCTAssertEqual(RecipeTitle.note(caption: "St. Louis ribs! Low and slow."), "Low and slow")
    }

    func test_cardTitleKeepsItsUntitledFallback() {
        XCTAssertEqual(RecipeTitle.from(caption: nil), String(localized: "Untitled"))
    }

    func test_noteIsTheCaptionAfterTheFirstSentence() {
        XCTAssertEqual(
            RecipeTitle.note(caption: "Sesame chicken. Crisp skin, sticky glaze!"),
            "Crisp skin, sticky glaze"
        )
        XCTAssertEqual(RecipeTitle.note(caption: "Sesame chicken\nRoast it hot."), "Roast it hot")
    }

    func test_aOneSentenceCaptionHasNoNote() {
        XCTAssertEqual(RecipeTitle.note(caption: "Sesame chicken."), "")
        XCTAssertEqual(RecipeTitle.note(caption: nil), "")
    }

    // MARK: - IngredientTicks

    func test_tickingTwiceUnticks() {
        var ticks = IngredientTicks()
        ticks.toggle(2)
        XCTAssertTrue(ticks.isTicked(2))
        ticks.toggle(2)
        XCTAssertFalse(ticks.isTicked(2))
        XCTAssertEqual(ticks.count, 0)
    }

    func test_duplicateIngredientsTickIndependently() {
        // PreviewData.recipe lists honey at rows 2 and 4; both share an id.
        let ingredients = PreviewData.recipe().ingredients
        XCTAssertEqual(ingredients[2].id, ingredients[4].id)
        var ticks = IngredientTicks()
        ticks.toggle(2)
        XCTAssertTrue(ticks.isTicked(2))
        XCTAssertFalse(ticks.isTicked(4))
        XCTAssertEqual(ticks.count, 1)
    }

    // MARK: - RecipeMeta

    func test_metaCapsulesShowTimeServesAndIngredientCount() {
        let capsules = RecipeMeta.capsules(for: PreviewData.recipe())
        XCTAssertEqual(capsules.map(\.text), ["35 min", "Serves 4", "5 ingredients"])
        XCTAssertEqual(capsules.map(\.systemImage), ["clock", "person.2", "list.bullet"])
    }

    func test_metaCapsulesLeaveOutMissingValues() {
        let capsules = RecipeMeta.capsules(for: PreviewData.post(1, "Toast", minutes: nil))
        XCTAssertEqual(capsules.map(\.text), ["Serves 2"])
    }

    func test_aRecordedZeroMinutesStillReads0Min() {
        XCTAssertEqual(RecipeMeta.timeLabel(minutes: 0), "0 min")
        XCTAssertEqual(RecipeMeta.timeLabel(minutes: 90), "1 hr 30 min")
    }

    func test_kickerIsTheFirstThreeTagsOrNothing() {
        XCTAssertEqual(RecipeMeta.kicker(tags: ["Weeknight", "Dinner", "Soup", "Vegan"]), "Weeknight · Dinner · Soup")
        XCTAssertNil(RecipeMeta.kicker(tags: []))
    }

    func test_cookNoteIsLabelledWithTheCook() {
        XCTAssertEqual(RecipeMeta.noteLabel(username: "noor"), "From noor")
    }

    // MARK: - CookModeCopy

    func test_cookModeRecipeLineNamesTheServingsWhenKnown() {
        XCTAssertEqual(CookModeCopy.recipeLine(title: "Dal", servings: 4), "Dal · serves 4")
        XCTAssertEqual(CookModeCopy.recipeLine(title: "Dal", servings: nil), "Dal")
    }

    // MARK: - PostLoadErrorCopy

    func test_notFoundOffersNoRetry() {
        let copy = PostLoadErrorCopy.decide(error: APIError.notFound)
        XCTAssertFalse(copy.allowsRetry)
        XCTAssertEqual(copy.title, "Post not available")
    }

    func test_otherFailuresOfferRetry() {
        let copy = PostLoadErrorCopy.decide(error: URLError(.notConnectedToInternet))
        XCTAssertTrue(copy.allowsRetry)
        XCTAssertEqual(copy.title, "Couldn't load this post")
    }
}
