import SwiftUI

/// W245: the redesign's two-way list switch (Components artboard, "list
/// switch"): a lift track holding equal pills; the selected one is a surface
/// pill with a soft shadow. Each option can carry a count.
struct SegmentedPills<Value: Hashable>: View {
    struct Option: Identifiable {
        let value: Value
        let title: String
        var count: Int?

        var id: Value {
            value
        }
    }

    let options: [Option]
    @Binding var selection: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: 2) {
            ForEach(options) { option in
                pill(option)
            }
        }
        .padding(4)
        .background(Capsule(style: .continuous).fill(Theme.lift))
    }

    private func pill(_ option: Option) -> some View {
        let isSelected = option.value == selection
        return Button {
            if reduceMotion {
                selection = option.value
            } else {
                withAnimation(.easeInOut(duration: 0.18)) { selection = option.value }
            }
        } label: {
            HStack(spacing: 5) {
                Text(option.title)
                    .scaledFont(14.5, weight: .semibold, relativeTo: .subheadline)
                if let count = option.count {
                    Text(count, format: .number)
                        .scaledFont(14.5, weight: .medium, relativeTo: .subheadline)
                        .opacity(0.75)
                }
            }
            .lineLimit(1)
            .foregroundStyle(isSelected ? Theme.text : Theme.muted)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background {
                if isSelected {
                    Capsule(style: .continuous)
                        .fill(Theme.surface)
                        .shadow(color: Theme.shadow, radius: 1.5, y: 1)
                }
            }
            .contentShape(Capsule(style: .continuous))
        }
        .buttonStyle(.borderless)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
    }
}

private struct SegmentedPillsGallery: View {
    @State private var tab = 0

    var body: some View {
        SegmentedPills(
            options: [
                .init(value: 0, title: "My recipes", count: 7),
                .init(value: 1, title: "Saved", count: 8),
            ],
            selection: $tab
        )
        .padding()
        .background(Theme.background)
    }
}

#Preview("SegmentedPills · light") {
    SegmentedPillsGallery()
}

#Preview("SegmentedPills · dark") {
    SegmentedPillsGallery().preferredColorScheme(.dark)
}

#Preview("SegmentedPills · largest text") {
    SegmentedPillsGallery().dynamicTypeSize(.accessibility5)
}
