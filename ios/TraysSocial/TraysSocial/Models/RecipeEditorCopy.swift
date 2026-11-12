import Foundation

/// W249: the recipe editor's Total time and Serves steppers. The values stay
/// the free-text strings the view models already post, so an empty field is
/// still "not set": minus leaves it empty and plus starts it at the canvas
/// default. A value that is not a number counts as empty.
struct EditorStepper: Equatable {
    let step: Int
    let range: ClosedRange<Int>
    let start: Int

    static let minutes = EditorStepper(step: 5, range: 5 ... 1440, start: 30)
    static let servings = EditorStepper(step: 1, range: 1 ... 24, start: 2)

    func increment(_ value: String) -> String {
        guard let current = Self.number(value) else { return String(start) }
        // A typed value above the range is left alone rather than pulled down.
        return String(max(current, min(current + step, range.upperBound)))
    }

    func decrement(_ value: String) -> String {
        guard let current = Self.number(value) else { return value }
        return String(max(range.lowerBound, current - step))
    }

    func canIncrement(_ value: String) -> Bool {
        guard let current = Self.number(value) else { return true }
        return current < range.upperBound
    }

    func canDecrement(_ value: String) -> Bool {
        guard let current = Self.number(value) else { return false }
        return current > range.lowerBound
    }

    private static func number(_ value: String) -> Int? {
        Int(value.trimmingCharacters(in: .whitespaces))
    }
}

/// W249: Return in a multi-line field inserts a line break instead of
/// submitting. The editor's name and new-step fields treat a trailing break
/// as Return, as the single-line fields they replace did.
enum ReturnKey {
    static func consume(_ newValue: String) -> (text: String, submitted: Bool) {
        guard let last = newValue.last, last.isNewline else { return (newValue, false) }
        var text = newValue
        while let end = text.last, end.isNewline {
            text.removeLast()
        }
        return (text, true)
    }
}

/// W249: what the editor's Preview shows: the recipe as it will read once
/// posted, including the half-typed ingredient, step and tool that
/// `publish()` adds on its own.
struct RecipeDraft: Equatable {
    struct Ingredient: Equatable {
        let amount: String
        let name: String
    }

    let title: String
    let note: String
    let kicker: String?
    let capsules: [RecipeMeta.Capsule]
    let ingredients: [Ingredient]
    let steps: [String]
    let tools: [String]

    @MainActor
    static func make(from viewModel: CreatePostViewModel) -> RecipeDraft {
        var ingredients = viewModel.ingredients.map {
            Ingredient(amount: amount(quantity: $0.quantity, unit: $0.unit), name: $0.name)
        }
        // The same guards `publish()` uses before it adds pending input.
        if !viewModel.newIngredientName.isEmpty {
            ingredients.append(Ingredient(
                amount: amount(quantity: viewModel.newIngredientQuantity, unit: viewModel.newIngredientUnit),
                name: viewModel.newIngredientName
            ))
        }
        var steps = viewModel.steps.map(\.description)
        if !viewModel.newStepText.isEmpty {
            steps.append(viewModel.newStepText)
        }
        var tools = viewModel.tools
        if !viewModel.newToolName.isEmpty {
            tools.append(viewModel.newToolName)
        }
        let tags = viewModel.tags.split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
        return RecipeDraft(
            title: RecipeTitle.from(caption: viewModel.caption, fallback: String(localized: "Untitled recipe")),
            note: RecipeTitle.note(caption: viewModel.caption),
            kicker: RecipeMeta.kicker(tags: tags),
            capsules: RecipeMeta.capsules(
                minutes: Int(viewModel.cookingTimeMinutes),
                servings: Int(viewModel.servings),
                ingredientCount: ingredients.count
            ),
            ingredients: ingredients,
            steps: steps,
            tools: tools
        )
    }

    /// "2 tbsp", "4", or "" — quantity and unit with empty parts skipped.
    static func amount(quantity: String, unit: String) -> String {
        [quantity, unit]
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }
}

/// W249: what the editor still needs before Post, so each missing piece can
/// say so in place (Create artboard, "Missing info"). It only decides what is
/// shown; posting and its rules stay the view model's. Pending input counts,
/// because `publish()` adds it.
struct EditorReadiness: Equatable {
    let needsName: Bool
    let needsIngredient: Bool
    let needsStep: Bool
    let needsPhoto: Bool

    static let nothingMissing = EditorReadiness(
        needsName: false,
        needsIngredient: false,
        needsStep: false,
        needsPhoto: false
    )

    var isReady: Bool {
        !(needsName || needsIngredient || needsStep || needsPhoto)
    }

    @MainActor
    static func of(_ viewModel: CreatePostViewModel) -> EditorReadiness {
        let isRecipe = viewModel.postType == .recipe
        let name = CaptionParts.name(of: viewModel.caption).trimmingCharacters(in: .whitespaces)
        return EditorReadiness(
            needsName: isRecipe && name.isEmpty,
            needsIngredient: isRecipe && viewModel.ingredients.isEmpty && viewModel.newIngredientName.isEmpty,
            needsStep: isRecipe && viewModel.steps.isEmpty && viewModel.newStepText.isEmpty,
            needsPhoto: viewModel.photoData == nil
        )
    }
}
