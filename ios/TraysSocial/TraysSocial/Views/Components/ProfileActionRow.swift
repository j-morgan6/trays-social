import SwiftUI

/// Single row in the Profile screen's sectioned action card. Mirrors
/// the prototype's row treatment (prototype.jsx lines 740-752):
/// 14pt medium label + optional right-aligned subtle count + a 14pt
/// chevron-right in `Theme.subtle(for:)`. The card itself is a single
/// rounded rectangle with internal hairline dividers — owned by the
/// caller, not this row.
struct ProfileActionRow: View {
    @Environment(\.colorScheme) private var colorScheme
    let label: String
    var count: String?
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 8) {
                Text(label)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)

                Spacer(minLength: 8)

                if let count {
                    Text(count)
                        .font(.system(size: 13))
                        .foregroundStyle(Theme.subtle(for: colorScheme))
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.subtle(for: colorScheme))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(count.map { "\(label), \($0)" } ?? label)
    }
}
