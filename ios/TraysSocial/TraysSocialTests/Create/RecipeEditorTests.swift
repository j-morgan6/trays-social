@testable import TraysSocial
import XCTest

/// W249: the recipe editor's name/line split over the caption, the Total
/// time and Serves steppers, Return in multi-line fields, and the Preview's
/// draft.
@MainActor
final class RecipeEditorTests: XCTestCase {
    // MARK: - CaptionParts

    func test_emptyCaptionHasNoNameAndNoLine() {
        XCTAssertEqual(CaptionParts.name(of: ""), "")
        XCTAssertEqual(CaptionParts.line(of: ""), "")
    }

    func test_captionWithoutABreakIsAllName() {
        XCTAssertEqual(CaptionParts.name(of: "Great pasta. Cooked it."), "Great pasta. Cooked it.")
        XCTAssertEqual(CaptionParts.line(of: "Great pasta. Cooked it."), "")
    }

    func test_nameAndLineSplitAtTheFirstBreak() {
        XCTAssertEqual(CaptionParts.name(of: "Dal\nWe make it on Sundays"), "Dal")
        XCTAssertEqual(CaptionParts.line(of: "Dal\nWe make it on Sundays"), "We make it on Sundays")
        XCTAssertEqual(CaptionParts.line(of: "A\r\nB"), "B")
    }

    func test_untouchedCaptionsRoundTripUnchanged() {
        for caption in ["", "Dal", "Dal\nNote", "A\n\nB", "Great pasta. Cooked it.", "A\nB\nC"] {
            let rejoined = CaptionParts.caption(name: CaptionParts.name(of: caption), line: CaptionParts.line(of: caption))
            XCTAssertEqual(rejoined, caption, "round trip of \(caption.debugDescription)")
        }
    }

    func test_emptyLineAddsNoTrailingBreak() {
        XCTAssertEqual(CaptionParts.caption(name: "Lemon pasta", line: ""), "Lemon pasta")
    }

    func test_aSpaceTypedFirstIntoTheLineIsKept() {
        let caption = CaptionParts.caption(name: "Lemon pasta", line: " ")
        XCTAssertEqual(CaptionParts.line(of: caption), " ")
        XCTAssertEqual(RecipeTitle.from(caption: caption, fallback: "X"), "Lemon pasta")
    }

    func test_nameStaysOneLine() {
        XCTAssertEqual(CaptionParts.caption(name: "Lemon pasta\n", line: ""), "Lemon pasta")
        XCTAssertEqual(CaptionParts.caption(name: "Lemon\npasta", line: "Quick"), "Lemon pasta\nQuick")
    }

    func test_lineWithNoNameSplitsBack() {
        let caption = CaptionParts.caption(name: "", line: "note")
        XCTAssertEqual(caption, "\nnote")
        XCTAssertEqual(CaptionParts.name(of: caption), "")
        XCTAssertEqual(CaptionParts.line(of: caption), "note")
    }

    func test_detailPageReadsTheNameAsTitleAndTheLineAsNote() {
        let caption = CaptionParts.caption(name: "Sesame chicken thighs", line: "We make this most Tuesdays")
        XCTAssertEqual(RecipeTitle.from(caption: caption, fallback: "X"), "Sesame chicken thighs")
        XCTAssertEqual(RecipeTitle.note(caption: caption), "We make this most Tuesdays")
    }

    // MARK: - EditorStepper

    func test_plusOnAnEmptyFieldStartsAtTheCanvasDefault() {
        XCTAssertEqual(EditorStepper.minutes.increment(""), "30")
        XCTAssertEqual(EditorStepper.servings.increment(""), "2")
        XCTAssertEqual(EditorStepper.servings.increment("abc"), "2")
    }

    func test_minusOnAnEmptyFieldLeavesItEmpty() {
        XCTAssertEqual(EditorStepper.minutes.decrement(""), "")
        XCTAssertFalse(EditorStepper.minutes.canDecrement(""))
        XCTAssertTrue(EditorStepper.minutes.canIncrement(""))
    }

    func test_stepsStayInsideTheRange() {
        XCTAssertEqual(EditorStepper.minutes.decrement("35"), "30")
        XCTAssertEqual(EditorStepper.minutes.decrement("5"), "5")
        XCTAssertEqual(EditorStepper.minutes.decrement("7"), "5")
        XCTAssertEqual(EditorStepper.minutes.increment("35"), "40")
        XCTAssertEqual(EditorStepper.servings.increment("24"), "24")
        XCTAssertFalse(EditorStepper.servings.canIncrement("24"))
        XCTAssertFalse(EditorStepper.servings.canDecrement("1"))
    }

    func test_aTypedValueAboveTheRangeIsNotPulledDown() {
        XCTAssertEqual(EditorStepper.servings.increment("40"), "40")
        XCTAssertEqual(EditorStepper.servings.decrement("40"), "39")
    }

    // MARK: - ReturnKey

    func test_trailingBreakIsReturn() {
        XCTAssertEqual(ReturnKey.consume("abc\n").text, "abc")
        XCTAssertTrue(ReturnKey.consume("abc\n").submitted)
    }

    func test_innerBreakIsText() {
        XCTAssertEqual(ReturnKey.consume("a\nb").text, "a\nb")
        XCTAssertFalse(ReturnKey.consume("a\nb").submitted)
    }

    // MARK: - RecipeDraft

    func test_draftIncludesThePendingIngredientAndStepThatPublishAdds() {
        let viewModel = CreatePostViewModel()
        viewModel.caption = "Dal\nSunday dinner"
        viewModel.cookingTimeMinutes = "40"
        viewModel.servings = "4"
        viewModel.ingredients = [.init(name: "red lentils", quantity: "1", unit: "cup")]
        viewModel.newIngredientName = "cumin"
        viewModel.newIngredientQuantity = "1"
        viewModel.newIngredientUnit = "tsp"
        viewModel.steps = [.init(description: "Rinse the lentils.")]
        viewModel.newStepText = "Simmer."
        viewModel.tags = "Weeknight, Vegan"

        let draft = RecipeDraft.make(from: viewModel)

        XCTAssertEqual(draft.title, "Dal")
        XCTAssertEqual(draft.note, "Sunday dinner")
        XCTAssertEqual(draft.kicker, "weeknight · vegan")
        XCTAssertEqual(draft.ingredients, [
            .init(amount: "1 cup", name: "red lentils"),
            .init(amount: "1 tsp", name: "cumin"),
        ])
        XCTAssertEqual(draft.steps, ["Rinse the lentils.", "Simmer."])
        XCTAssertEqual(draft.capsules.map(\.systemImage), ["clock", "person.2", "list.bullet"])
        XCTAssertEqual(draft.capsules.last?.text, String(localized: "\(2) ingredients"))
    }

    func test_draftLeavesOutEmptyPendingInputAndFallsBackToUntitled() {
        let viewModel = CreatePostViewModel()
        viewModel.cookingTimeMinutes = "soon"
        let draft = RecipeDraft.make(from: viewModel)
        XCTAssertEqual(draft.title, String(localized: "Untitled recipe"))
        XCTAssertTrue(draft.ingredients.isEmpty)
        XCTAssertTrue(draft.steps.isEmpty)
        XCTAssertTrue(draft.capsules.isEmpty)
        XCTAssertNil(draft.kicker)
    }

    func test_amountSkipsEmptyParts() {
        XCTAssertEqual(RecipeDraft.amount(quantity: "2", unit: "tbsp"), "2 tbsp")
        XCTAssertEqual(RecipeDraft.amount(quantity: "4", unit: ""), "4")
        XCTAssertEqual(RecipeDraft.amount(quantity: " ", unit: "pinch"), "pinch")
        XCTAssertEqual(RecipeDraft.amount(quantity: "", unit: ""), "")
    }

    func test_draftIncludesToolsAndThePendingTool() {
        let viewModel = CreatePostViewModel()
        viewModel.tools = ["Cast iron pan"]
        viewModel.newToolName = "Tongs"
        XCTAssertEqual(RecipeDraft.make(from: viewModel).tools, ["Cast iron pan", "Tongs"])
    }

    // MARK: - EditorReadiness

    func test_emptyRecipeNeedsEveryPiece() {
        let readiness = EditorReadiness.of(CreatePostViewModel())
        XCTAssertEqual(
            readiness,
            EditorReadiness(needsName: true, needsIngredient: true, needsStep: true, needsPhoto: true, needsTime: true)
        )
        XCTAssertFalse(readiness.isReady)
    }

    func test_pendingInputCountsAndALineAloneIsNoName() {
        let viewModel = CreatePostViewModel()
        viewModel.caption = "\nJust a line"
        viewModel.cookingTimeMinutes = "30"
        viewModel.newIngredientName = "cumin"
        viewModel.newStepText = "Simmer."
        viewModel.photoData = Data([0])
        let readiness = EditorReadiness.of(viewModel)
        XCTAssertEqual(
            readiness,
            EditorReadiness(
                needsName: true, needsIngredient: false,
                needsStep: false, needsPhoto: false, needsTime: false
            )
        )
        viewModel.caption = "Dal\nJust a line"
        XCTAssertTrue(EditorReadiness.of(viewModel).isReady)
    }

    func test_aPhotoPostNeedsOnlyAPhoto() {
        let viewModel = CreatePostViewModel()
        viewModel.postType = .post
        XCTAssertEqual(
            EditorReadiness.of(viewModel),
            EditorReadiness(
                needsName: false, needsIngredient: false,
                needsStep: false, needsPhoto: true, needsTime: false
            )
        )
    }

    // MARK: - EditorReadiness: total time (D124)

    /// A recipe with everything in except, unless given, the total time.
    private func recipe(minutes: String = "") -> CreatePostViewModel {
        let viewModel = CreatePostViewModel()
        viewModel.postType = .recipe
        viewModel.caption = "Dal"
        viewModel.newIngredientName = "red lentils"
        viewModel.newStepText = "Simmer."
        viewModel.photoData = Data([0])
        viewModel.cookingTimeMinutes = minutes
        return viewModel
    }

    func test_aRecipeWithAPositiveTimeDoesNotNeedTime() {
        let readiness = EditorReadiness.of(recipe(minutes: "30"))
        XCTAssertFalse(readiness.needsTime)
        XCTAssertTrue(readiness.isReady)
    }

    func test_zeroTimeNeedsTimeAndOneMinuteDoesNot() {
        XCTAssertTrue(EditorReadiness.of(recipe(minutes: "0")).needsTime)
        XCTAssertTrue(EditorReadiness.of(recipe(minutes: "-5")).needsTime)
        XCTAssertFalse(EditorReadiness.of(recipe(minutes: "1")).needsTime)
    }

    func test_nonNumericTimeStillNeedsTime() {
        for minutes in ["", "soon", "5.5", "30 min"] {
            XCTAssertTrue(EditorReadiness.of(recipe(minutes: minutes)).needsTime, minutes.debugDescription)
        }
    }

    func test_aTypedTimeAboveTheStepperRangeIsATime() {
        XCTAssertFalse(EditorReadiness.of(recipe(minutes: "2000")).needsTime)
    }

    /// `publish()` parses the time untrimmed and sends none for " 30 ", which
    /// the server would refuse, so readiness must not call it ready.
    func test_aTimeWithSpacesAroundItNeedsTimeBecausePublishWouldDropIt() {
        XCTAssertNil(Int(" 30 "))
        XCTAssertTrue(EditorReadiness.of(recipe(minutes: " 30 ")).needsTime)
    }

    /// Create stores the time through `EditorStepper.typed`, so whitespace
    /// around a typed or pasted number is ignored and the time counts.
    func test_whitespaceAroundATypedTimeIsIgnored() {
        XCTAssertEqual(EditorStepper.typed(" 30 "), "30")
        XCTAssertEqual(EditorStepper.typed(" "), "")
        XCTAssertFalse(EditorReadiness.of(recipe(minutes: EditorStepper.typed(" 30 "))).needsTime)
    }

    func test_aPhotoPostNeverNeedsTime() {
        for minutes in ["", "0", "soon"] {
            let viewModel = CreatePostViewModel()
            viewModel.postType = .post
            viewModel.photoData = Data([0])
            viewModel.cookingTimeMinutes = minutes
            let readiness = EditorReadiness.of(viewModel)
            XCTAssertFalse(readiness.needsTime, minutes.debugDescription)
            XCTAssertTrue(readiness.isReady, minutes.debugDescription)
        }
    }

    func test_isReadyIsFalseWhileOnlyTheTimeIsMissing() {
        let readiness = EditorReadiness.of(recipe())
        XCTAssertEqual(
            readiness,
            EditorReadiness(
                needsName: false, needsIngredient: false,
                needsStep: false, needsPhoto: false, needsTime: true
            )
        )
        XCTAssertFalse(readiness.isReady)
    }

    func test_nothingMissingFlagsNoTime() {
        XCTAssertFalse(EditorReadiness.nothingMissing.needsTime)
        XCTAssertTrue(EditorReadiness.nothingMissing.isReady)
    }

    // MARK: - RecipeMeta overload

    func test_capsuleOverloadMatchesThePostVersion() {
        XCTAssertEqual(
            RecipeMeta.capsules(minutes: 35, servings: 2, ingredientCount: 1).map(\.text),
            [RecipeMeta.timeLabel(minutes: 35), String(localized: "Serves \(2)"), String(localized: "1 ingredient")]
        )
        XCTAssertTrue(RecipeMeta.capsules(minutes: nil, servings: nil, ingredientCount: 0).isEmpty)
    }
}
