import SwiftUI

/// W249: the editor's focusable fields, shared by Create and Edit.
enum EditorField: Hashable {
    case name, line, caption, minutes, servings, amount, unit, ingredient, step, tool, tags
}

/// W249: the Basics card (Create artboard): Recipe name, A line about it, and
/// the Total time / Serves tiles. Name and line are two views of the one
/// caption string (`CaptionParts`), so nothing about the posted payload
/// changes. A plain photo post keeps its single Caption field.
struct RecipeBasicsCard: View {
    @Binding var caption: String
    @Binding var minutes: String
    @Binding var servings: String
    let showsRecipeFields: Bool
    var nameNeedsAttention = false
    /// D124: Create sets this after a Post tap when the recipe has no time.
    var timeNeedsAttention = false
    var focus: FocusState<EditorField?>.Binding

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        EditorCard {
            if showsRecipeFields {
                recipeFields
            } else {
                captionField
            }
        }
    }

    @ViewBuilder private var recipeFields: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: String(localized: "Recipe name"))
            TextField(
                "",
                text: nameBinding,
                prompt: Text("e.g. Sesame chicken thighs").foregroundStyle(Theme.muted),
                axis: .vertical
            )
            .lineLimit(1 ... 4)
            .roundedFont(20, weight: .heavy, relativeTo: .title3)
            .submitLabel(.next)
            .focused(focus, equals: .name)
            .padding(.vertical, 12)
            .trayField(isFocused: focus.wrappedValue == .name, needsAttention: nameNeedsAttention)
            .accessibilityLabel(Text("Recipe name"))
            if nameNeedsAttention {
                EditorAttentionNote(message: String(localized: "Give it a name."))
            }
        }
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: String(localized: "A line about it"), isOptional: true)
            TextField(
                "",
                text: lineBinding,
                prompt: Text("When you make it, and what makes it good").foregroundStyle(Theme.muted),
                axis: .vertical
            )
            .lineLimit(2 ... 6)
            .scaledFont(16, relativeTo: .body)
            .focused(focus, equals: .line)
            .padding(.vertical, 12)
            .trayField(isFocused: focus.wrappedValue == .line, alignment: .topLeading)
            .accessibilityLabel(Text("A line about it"))
        }
        .padding(.top, 2)
        let tiles = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(spacing: 12))
            : AnyLayout(HStackLayout(alignment: .top, spacing: 12))
        tiles {
            VStack(alignment: .leading, spacing: 8) {
                CountStepperTile(
                    label: String(localized: "Total time"),
                    value: $minutes,
                    stepper: .minutes,
                    suffix: String(localized: "min"),
                    decrementLabel: String(localized: "Less time"),
                    incrementLabel: String(localized: "More time"),
                    field: EditorField.minutes,
                    focus: focus,
                    needsAttention: timeNeedsAttention
                )
                if timeNeedsAttention {
                    EditorAttentionNote(message: String(localized: "Add a total time."))
                }
            }
            CountStepperTile(
                label: String(localized: "Serves"),
                value: $servings,
                stepper: .servings,
                decrementLabel: String(localized: "Fewer servings"),
                incrementLabel: String(localized: "More servings"),
                field: EditorField.servings,
                focus: focus
            )
        }
        .padding(.top, 2)
    }

    private var captionField: some View {
        VStack(alignment: .leading, spacing: 8) {
            EditorFieldLabel(text: String(localized: "Caption"))
            TextField("", text: $caption, prompt: Text("Caption").foregroundStyle(Theme.muted), axis: .vertical)
                .lineLimit(3 ... 6)
                .scaledFont(16, relativeTo: .body)
                .focused(focus, equals: .caption)
                .padding(.vertical, 12)
                .trayField(isFocused: focus.wrappedValue == .caption, alignment: .topLeading)
                .accessibilityLabel(Text("Caption"))
        }
    }

    /// The text before the caption's first line break. Return, wherever the
    /// cursor is, moves on to the line field rather than breaking the name.
    private var nameBinding: Binding<String> {
        Binding(
            get: { CaptionParts.name(of: caption) },
            set: { newValue in
                let typed = ReturnKey.consume(newValue)
                caption = CaptionParts.caption(name: typed.text, line: CaptionParts.line(of: caption))
                if typed.submitted || newValue.contains(where: \.isNewline) {
                    focus.wrappedValue = .line
                }
            }
        )
    }

    private var lineBinding: Binding<String> {
        Binding(
            get: { CaptionParts.line(of: caption) },
            set: { newValue in
                caption = CaptionParts.caption(name: CaptionParts.name(of: caption), line: newValue)
            }
        )
    }
}
