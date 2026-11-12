import SwiftUI

// W249: the editor's Ingredients, Steps, Tools and Tags cards (Create
// artboard). Saved rows are read-only lift rows with a remove button; only
// the row for the next entry is a field, because the view model's entries
// are immutable and adding works exactly as before.

struct IngredientsCard: View {
    @Bindable var viewModel: CreatePostViewModel
    var needsAttention = false
    var focus: FocusState<EditorField?>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        EditorCard(String(localized: "Ingredients"), aside: countLabel) {
            ForEach(Array(viewModel.ingredients.enumerated()), id: \.element.id) { index, ingredient in
                savedRow(ingredient, at: index)
            }
            entryRow
            if needsAttention {
                EditorAttentionNote(message: String(localized: "Add at least one ingredient."))
            }
            Button(String(localized: "Add ingredient")) {
                viewModel.addIngredient()
                focus.wrappedValue = .amount
            }
            .buttonStyle(.trayAddRow)
            .disabled(viewModel.newIngredientName.isEmpty)
            .padding(.top, 2)
        }
    }

    private var countLabel: String {
        let count = viewModel.ingredients.count
        return count == 1 ? String(localized: "1 ingredient") : String(localized: "\(count) ingredients")
    }

    private func savedRow(_ ingredient: CreatePostViewModel.IngredientEntry, at index: Int) -> some View {
        let amount = RecipeDraft.amount(quantity: ingredient.quantity, unit: ingredient.unit)
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 2))
            : AnyLayout(HStackLayout(alignment: .firstTextBaseline, spacing: 12))
        return HStack(spacing: 4) {
            layout {
                if !amount.isEmpty {
                    Text(amount)
                        .scaledFont(15.5, weight: .semibold, relativeTo: .body)
                        .frame(minWidth: 70, alignment: .leading)
                }
                Text(ingredient.name)
                    .scaledFont(16, relativeTo: .body)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .foregroundStyle(Theme.text)
            .padding(.vertical, 12)
            .accessibilityElement(children: .combine)
            RemoveRowButton(label: String(localized: "Remove \(ingredient.name)")) {
                viewModel.removeIngredient(at: index)
            }
        }
        .padding(.leading, 14)
        .frame(minHeight: 50)
        .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lift))
    }

    private var entryRow: some View {
        let layout = dynamicTypeSize >= .xxxLarge
            ? AnyLayout(VStackLayout(spacing: 8))
            : AnyLayout(HStackLayout(spacing: 8))
        return layout {
            TextField("", text: $viewModel.newIngredientQuantity, prompt: Text("Amount").foregroundStyle(Theme.muted))
                .submitLabel(.next)
                .onSubmit { focus.wrappedValue = .unit }
                .focused(focus, equals: .amount)
                .trayField(isFocused: focus.wrappedValue == .amount)
                .frame(maxWidth: dynamicTypeSize >= .xxxLarge ? .infinity : 88)
                .accessibilityLabel(Text("Amount"))
            TextField("", text: $viewModel.newIngredientUnit, prompt: Text("Unit").foregroundStyle(Theme.muted))
                .submitLabel(.next)
                .onSubmit { focus.wrappedValue = .ingredient }
                .focused(focus, equals: .unit)
                .trayField(isFocused: focus.wrappedValue == .unit)
                .frame(maxWidth: dynamicTypeSize >= .xxxLarge ? .infinity : 72)
                .accessibilityLabel(Text("Unit"))
            TextField("", text: $viewModel.newIngredientName, prompt: Text("Ingredient").foregroundStyle(Theme.muted))
                .submitLabel(.done)
                .onSubmit {
                    viewModel.addIngredient()
                    focus.wrappedValue = .amount
                }
                .focused(focus, equals: .ingredient)
                .trayField(isFocused: focus.wrappedValue == .ingredient)
                .accessibilityLabel(Text("Ingredient"))
        }
        .scaledFont(16, relativeTo: .body)
    }
}

struct StepsCard: View {
    @Bindable var viewModel: CreatePostViewModel
    var needsAttention = false
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        EditorCard(String(localized: "Steps"), aside: countLabel) {
            ForEach(Array(viewModel.steps.enumerated()), id: \.element.id) { index, step in
                savedRow(step, number: index + 1, at: index)
                Divider().overlay(Theme.hairline)
            }
            HStack(alignment: .top, spacing: 12) {
                StepNumberDisc(number: viewModel.steps.count + 1)
                    .padding(.top, 10)
                TextField(
                    "",
                    text: stepBinding,
                    prompt: Text("What to do in this step").foregroundStyle(Theme.muted),
                    axis: .vertical
                )
                .lineLimit(2 ... 6)
                .scaledFont(16, relativeTo: .body)
                .submitLabel(.done)
                .focused(focus, equals: .step)
                .padding(.vertical, 12)
                .trayField(isFocused: focus.wrappedValue == .step, alignment: .topLeading)
                .accessibilityLabel(Text("Step \(viewModel.steps.count + 1)"))
            }
            if needsAttention {
                EditorAttentionNote(message: String(localized: "Add at least one step."))
            }
            Button(String(localized: "Add step")) {
                viewModel.addStep()
                focus.wrappedValue = .step
            }
            .buttonStyle(.trayAddRow)
            .disabled(viewModel.newStepText.isEmpty)
            .padding(.top, 2)
        }
    }

    private var countLabel: String {
        let count = viewModel.steps.count
        return count == 1 ? String(localized: "1 step") : String(localized: "\(count) steps")
    }

    /// Return adds the step, as the single-line field it replaces did.
    private var stepBinding: Binding<String> {
        Binding(
            get: { viewModel.newStepText },
            set: { newValue in
                let typed = ReturnKey.consume(newValue)
                viewModel.newStepText = typed.text
                if typed.submitted {
                    viewModel.addStep()
                }
            }
        )
    }

    private func savedRow(_ step: CreatePostViewModel.StepEntry, number: Int, at index: Int) -> some View {
        HStack(alignment: .top, spacing: 12) {
            StepNumberDisc(number: number)
                .padding(.top, 10)
            Text(step.description)
                .scaledFont(16, relativeTo: .body)
                .lineSpacing(3)
                .foregroundStyle(Theme.text)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
                .padding(.horizontal, 14)
                .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(Theme.lift))
                .accessibilityLabel(Text("Step \(number). \(step.description)"))
            RemoveRowButton(label: String(localized: "Remove step \(number)")) {
                viewModel.removeStep(at: index)
            }
        }
    }
}

struct ToolsCard: View {
    @Bindable var viewModel: CreatePostViewModel
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        EditorCard(String(localized: "Tools"), aside: String(localized: "Optional")) {
            if !viewModel.tools.isEmpty {
                FlowLayout(spacing: 8) {
                    ForEach(Array(viewModel.tools.enumerated()), id: \.offset) { index, tool in
                        IngredientChip(name: tool) { viewModel.removeTool(at: index) }
                    }
                }
            }
            TextField("", text: $viewModel.newToolName, prompt: Text("Tool name").foregroundStyle(Theme.muted))
                .scaledFont(16, relativeTo: .body)
                .submitLabel(.done)
                .onSubmit { viewModel.addTool() }
                .focused(focus, equals: .tool)
                .trayField(isFocused: focus.wrappedValue == .tool)
                .accessibilityLabel(Text("Tool name"))
            Button(String(localized: "Add tool")) { viewModel.addTool() }
                .buttonStyle(.trayAddRow)
                .disabled(viewModel.newToolName.isEmpty)
        }
    }
}

struct TagsCard: View {
    @Bindable var viewModel: CreatePostViewModel
    var focus: FocusState<EditorField?>.Binding

    var body: some View {
        EditorCard(String(localized: "Tags"), aside: String(localized: "Optional")) {
            TextField("", text: $viewModel.tags, prompt: Text("weeknight, chicken").foregroundStyle(Theme.muted))
                .scaledFont(16, relativeTo: .body)
                .textInputAutocapitalization(.never)
                .focused(focus, equals: .tags)
                .trayField(isFocused: focus.wrappedValue == .tags)
                .accessibilityLabel(Text("Tags"))
            Text("Separate tags with commas")
                .scaledFont(13, relativeTo: .footnote)
                .foregroundStyle(Theme.muted)
        }
    }
}

/// The amber-muted numbered disc beside a step.
struct StepNumberDisc: View {
    let number: Int

    var body: some View {
        Text("\(number)")
            .roundedFont(14, weight: .heavy, relativeTo: .subheadline)
            .minimumScaleFactor(0.5)
            .foregroundStyle(Theme.text)
            .frame(width: 30, height: 30)
            .background(Circle().fill(Theme.accentMuted))
            .accessibilityHidden(true)
    }
}

/// A 44pt muted remove control at the end of a saved row.
struct RemoveRowButton: View {
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Theme.muted)
                .frame(width: 44, height: 44)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(Text(label))
    }
}
