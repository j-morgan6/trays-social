import PhotosUI
import SwiftUI

// W249: pieces the recipe editor and the edit form share (Create artboard):
// the photo slot, the Total time / Serves stepper tile and the floating
// action bar with the amber button.

/// The photo slot: a dashed "Add a photo" block until there is a photo, then
/// the photo at 4:3 with a "Change" pill. Needing a photo turns the dashed
/// border into a solid amber one, never red.
struct EditorPhotoSlot: View {
    let image: Image?
    var remoteURL: URL?
    @Binding var selection: PhotosPickerItem?
    var needsAttention = false
    var emptySubtitle = String(localized: "Needed to post. A clear shot of the finished dish works best.")

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        if image != nil || remoteURL != nil {
            filled
        } else {
            empty
        }
    }

    private var filled: some View {
        Group {
            if let image {
                Color.clear
                    .overlay { image.resizable().scaledToFill() }
                    .clipShape(shape)
                    .accessibilityHidden(true)
            } else {
                PhotoSlot(url: remoteURL, cornerRadius: 22)
            }
        }
        .aspectRatio(4 / 3, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .overlay {
            if needsAttention {
                shape.strokeBorder(Theme.accent, lineWidth: 1.5)
            }
        }
        .overlay(alignment: .bottomTrailing) {
            PhotosPicker(selection: $selection, matching: .images) {
                ChangePhotoPill()
            }
            .accessibilityLabel(Text("Change photo"))
            .padding(10)
        }
    }

    private var empty: some View {
        PhotosPicker(selection: $selection, matching: .images) {
            AddPhotoBlock(subtitle: emptySubtitle, needsAttention: needsAttention)
        }
        .buttonStyle(.plain)
    }
}

/// The "Change" pill over a photo. A View of its own because the picker's
/// label closure is not main-actor isolated.
private struct ChangePhotoPill: View {
    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "camera")
                .accessibilityHidden(true)
            Text("Change")
        }
        .scaledFont(14, weight: .semibold, relativeTo: .subheadline)
        .foregroundStyle(Theme.text)
        .padding(.horizontal, 14)
        .frame(minHeight: 44)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Theme.pill)
            }
        }
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
        .contentShape(Capsule(style: .continuous))
    }
}

/// The empty slot: camera, "Add a photo" and a muted line on a dashed block.
private struct AddPhotoBlock: View {
    let subtitle: String
    let needsAttention: Bool

    private let shape = RoundedRectangle(cornerRadius: 22, style: .continuous)

    var body: some View {
        ZStack {
            // Holds the 4:3 shape; larger text grows the block instead of clipping.
            Color.clear.aspectRatio(4 / 3, contentMode: .fit)
            VStack(spacing: 8) {
                Image(systemName: "camera")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(Theme.primaryInk)
                    .accessibilityHidden(true)
                Text("Add a photo")
                    .roundedFont(17, weight: .heavy, relativeTo: .headline)
                    .foregroundStyle(Theme.text)
                Text(subtitle)
                    .scaledFont(13, relativeTo: .footnote)
                    .foregroundStyle(Theme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
        }
        .frame(maxWidth: .infinity)
        .background(shape.fill(Theme.surface))
        .overlay {
            if needsAttention {
                shape.strokeBorder(Theme.accent, lineWidth: 1.5)
            } else {
                shape.strokeBorder(Theme.hairlineStrong, style: StrokeStyle(lineWidth: 1.5, dash: [6, 5]))
            }
        }
        .contentShape(shape)
    }
}

/// Total time or Serves: a small tile with a label and a minus / value /
/// plus row. The value is the same free-text field the view model posts; an
/// empty one reads "Set".
struct CountStepperTile<Field: Hashable>: View {
    let label: String
    @Binding var value: String
    let stepper: EditorStepper
    var suffix: String?
    let decrementLabel: String
    let incrementLabel: String
    let field: Field
    var focus: FocusState<Field?>.Binding

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .scaledFont(12.5, weight: .semibold, relativeTo: .caption)
                .foregroundStyle(Theme.muted)
            HStack(spacing: 4) {
                stepButton("minus", label: decrementLabel, enabled: stepper.canDecrement(value)) {
                    value = stepper.decrement(value)
                }
                HStack(spacing: 3) {
                    TextField("", text: $value, prompt: Text("Set").foregroundStyle(Theme.muted))
                        .keyboardType(.numberPad)
                        .multilineTextAlignment(.center)
                        .fixedSize()
                        .focused(focus, equals: field)
                    if let suffix, !value.isEmpty {
                        Text(suffix)
                    }
                }
                .roundedFont(17, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Theme.text)
                .frame(maxWidth: .infinity)
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(label))
                stepButton("plus", label: incrementLabel, enabled: stepper.canIncrement(value)) {
                    value = stepper.increment(value)
                }
            }
        }
        .padding(EdgeInsets(top: 10, leading: 14, bottom: 10, trailing: 10))
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Theme.background))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Theme.hairlineStrong, lineWidth: 1)
        )
    }

    private func stepButton(
        _ systemImage: String,
        label: String,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Theme.text)
                .frame(width: 44, height: 44)
                .background(Circle().fill(Theme.surface).shadow(color: Theme.shadow, radius: 1, y: 1))
                .overlay(Circle().strokeBorder(Theme.hairline, lineWidth: 1))
                .contentShape(Circle())
                .opacity(enabled ? 1 : 0.45)
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .accessibilityLabel(Text(label))
    }
}

/// The floating bar at the bottom of the editor: a pill holding the full
/// width amber action, which shows a spinner while it is busy.
struct EditorActionBar: View {
    let title: String
    let busyLabel: String
    let isBusy: Bool
    /// Quiet (lift, muted) until everything needed is in, as on the canvas.
    /// It stays tappable: a tap with something missing shows what is needed.
    var looksReady = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            if isBusy {
                ProgressView()
                    .tint(Theme.inkOnAccent)
                    .accessibilityLabel(Text(busyLabel))
            } else {
                Text(title)
                    .lineLimit(1)
            }
        }
        .buttonStyle(EditorActionStyle(looksReady: looksReady || isBusy))
        .disabled(isBusy)
        .padding(5)
        .background {
            ZStack {
                Capsule(style: .continuous).fill(.ultraThinMaterial)
                Capsule(style: .continuous).fill(Theme.pill)
            }
        }
        .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
        .shadow(color: Theme.shadow, radius: 12, y: 8)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }
}

/// The bar's button: the amber accent when ready (and while busy), a quiet
/// lift capsule with muted text otherwise. Never dimmed while busy.
private struct EditorActionStyle: ButtonStyle {
    let looksReady: Bool

    func makeBody(configuration: ButtonStyleConfiguration) -> some View {
        if looksReady {
            AccentButtonStyle(fillsWidth: true, minHeight: 48, dimsWhenDisabled: false)
                .makeBody(configuration: configuration)
        } else {
            configuration.label
                .scaledFont(15.5, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Theme.muted)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity, minHeight: 48)
                .background(Capsule(style: .continuous).fill(Theme.lift))
                .overlay(Capsule(style: .continuous).strokeBorder(Theme.hairlineStrong, lineWidth: 1))
                .contentShape(Capsule(style: .continuous))
                .opacity(configuration.isPressed ? 0.8 : 1)
        }
    }
}
