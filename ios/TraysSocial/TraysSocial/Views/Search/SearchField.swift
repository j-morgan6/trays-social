import SwiftUI

/// W243: the single search box (Main artboard, Search). A surface capsule
/// with a soft border; focused, it takes an amber ring and an amber-muted
/// halo. Return hands the text to `onSubmit` (W205: it becomes a chip).
struct SearchField: View {
    @Binding var text: String
    var isFocused: FocusState<Bool>.Binding
    let showsClear: Bool
    let onSubmit: () -> Void
    let onClear: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.muted)
                .accessibilityHidden(true)
            TextField(
                "",
                text: $text,
                prompt: Text("Search recipes, ingredients, cooks…").foregroundStyle(Theme.muted)
            )
            .scaledFont(16, relativeTo: .body)
            .foregroundStyle(Theme.text)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.return)
            .focused(isFocused)
            .onSubmit(onSubmit)
            .accessibilityLabel(Text("Search recipes, ingredients, cooks"))
            if showsClear {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18, weight: .regular))
                        .foregroundStyle(Theme.muted)
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text("Clear search"))
            }
        }
        .padding(.leading, 16)
        .padding(.trailing, 6)
        .frame(minHeight: 56)
        .background {
            Capsule(style: .continuous)
                .fill(Theme.surface)
                .shadow(color: isFocused.wrappedValue ? .clear : Theme.shadow, radius: 8, y: 4)
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    isFocused.wrappedValue ? Theme.accent : Theme.border,
                    lineWidth: isFocused.wrappedValue ? 1.5 : 1
                )
        }
        .background {
            // The amber-muted halo sits 4pt outside the capsule when focused.
            Capsule(style: .continuous)
                .fill(Theme.accentMuted)
                .padding(-4)
                .opacity(isFocused.wrappedValue ? 1 : 0)
        }
        .animation(.easeOut(duration: 0.15), value: isFocused.wrappedValue)
    }
}
