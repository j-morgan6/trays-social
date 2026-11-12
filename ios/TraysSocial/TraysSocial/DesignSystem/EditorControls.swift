import SwiftUI

// W249: the redesign's editor controls (Create artboard): the text field box,
// the mint add-row button, the in-place amber note for missing information,
// and the rounded editor card. Shared by the recipe editor and its edit form.

/// The field box: page background, 14pt continuous corners, a strong hairline
/// ring, at least 50pt high. Focus adds the amber ring and a soft amber glow;
/// a field that needs attention gets the amber ring alone, never red.
struct TrayFieldBox: ViewModifier {
    var isFocused = false
    var needsAttention = false
    var minHeight: CGFloat = 50
    var alignment: Alignment = .leading
    /// W251: the sign-in fields sit on `surface` (Login artboard); the
    /// editor keeps the page background.
    var fill: Color = Theme.background

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        content
            .textFieldStyle(.plain)
            .foregroundStyle(Theme.text)
            .tint(Theme.primaryInk)
            .padding(.horizontal, 14)
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: alignment)
            .background(shape.fill(fill))
            .overlay {
                if isFocused || needsAttention {
                    shape.strokeBorder(Theme.accent, lineWidth: 1.5)
                } else {
                    shape.strokeBorder(Theme.hairlineStrong, lineWidth: 1)
                }
            }
            .background {
                if isFocused {
                    shape.inset(by: -4).fill(Theme.accentMuted)
                }
            }
    }
}

extension View {
    /// Wrap a text field (or read-only text) in the editor's field box.
    func trayField(
        isFocused: Bool = false,
        needsAttention: Bool = false,
        minHeight: CGFloat = 50,
        alignment: Alignment = .leading,
        fill: Color = Theme.background
    ) -> some View {
        modifier(TrayFieldBox(
            isFocused: isFocused,
            needsAttention: needsAttention,
            minHeight: minHeight,
            alignment: alignment,
            fill: fill
        ))
    }
}

/// The add-row button: a mint capsule with primary ink text and a leading
/// plus, 44pt high ("Add ingredient", "Add step").
struct AddRowButtonStyle: ButtonStyle {
    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        AddRowBody(label: configuration.label, isPressed: configuration.isPressed)
    }
}

private struct AddRowBody<Label: View>: View {
    @Environment(\.isEnabled) private var isEnabled
    let label: Label
    let isPressed: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "plus")
                .font(.system(size: 15, weight: .bold))
                .accessibilityHidden(true)
            label
        }
        .scaledFont(15, weight: .semibold, relativeTo: .body)
        .foregroundStyle(Theme.primaryInk)
        .padding(.leading, 12)
        .padding(.trailing, 16)
        .frame(minHeight: 44)
        .background(Capsule(style: .continuous).fill(Theme.mintTint))
        .contentShape(Capsule(style: .continuous))
        .opacity(isPressed ? 0.75 : (isEnabled ? 1 : 0.55))
    }
}

extension ButtonStyle where Self == AddRowButtonStyle {
    static var trayAddRow: Self {
        .init()
    }
}

/// The in-place note under a field or card that says what it still needs:
/// amber-muted block, an exclamation symbol, body-colour text.
struct EditorAttentionNote: View {
    let message: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: "exclamationmark.circle")
                .accessibilityHidden(true)
            Text(message)
                .fixedSize(horizontal: false, vertical: true)
        }
        .scaledFont(13.5, weight: .medium, relativeTo: .footnote)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(Theme.accentMuted))
        .accessibilityElement(children: .combine)
    }
}

/// A rounded editor card: soft card surface, 22pt corners, 16pt padding, a
/// rounded 18pt heading with an optional muted aside on the right.
struct EditorCard<Content: View>: View {
    let title: String?
    var aside: String?
    @ViewBuilder let content: Content

    init(_ title: String? = nil, aside: String? = nil, @ViewBuilder content: () -> Content) {
        self.title = title
        self.aside = aside
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let title {
                HStack(alignment: .firstTextBaseline, spacing: 10) {
                    Text(title)
                        .roundedFont(18, weight: .heavy, relativeTo: .headline)
                        .foregroundStyle(Theme.text)
                        .accessibilityAddTraits(.isHeader)
                    Spacer(minLength: 0)
                    if let aside {
                        Text(aside)
                            .scaledFont(13, relativeTo: .footnote)
                            .foregroundStyle(Theme.muted)
                    }
                }
            }
            content
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(cornerRadius: 22)
    }
}

/// A field label above a field: 13.5pt semibold, with an optional muted
/// "(optional)".
struct EditorFieldLabel: View {
    let text: String
    var isOptional = false

    var body: some View {
        HStack(spacing: 4) {
            Text(text)
                .foregroundStyle(Theme.text)
            if isOptional {
                Text("(optional)")
                    .fontWeight(.regular)
                    .foregroundStyle(Theme.muted)
            }
        }
        .scaledFont(13.5, weight: .semibold, relativeTo: .subheadline)
    }
}

private struct EditorControlsGallery: View {
    @State private var name = "Sesame chicken thighs"
    @State private var empty = ""

    var body: some View {
        VStack(spacing: 14) {
            EditorCard("Basics") {
                EditorFieldLabel(text: "Recipe name")
                TextField("e.g. Sesame chicken thighs", text: $name)
                    .roundedFont(20, weight: .heavy, relativeTo: .title3)
                    .trayField(isFocused: true)
                EditorFieldLabel(text: "A line about it", isOptional: true)
                TextField("When you make it, and what makes it good", text: $empty)
                    .trayField(needsAttention: true)
                EditorAttentionNote(message: "Give it a name.")
            }
            EditorCard("Ingredients", aside: "2 ingredients") {
                Button("Add ingredient") {}
                    .buttonStyle(.trayAddRow)
            }
        }
        .padding()
        .background(Theme.background)
    }
}

#Preview("Editor controls · light") {
    EditorControlsGallery().preferredColorScheme(.light)
}

#Preview("Editor controls · dark") {
    EditorControlsGallery().preferredColorScheme(.dark)
}

#Preview("Editor controls · largest text") {
    EditorControlsGallery().dynamicTypeSize(.accessibility5)
}
