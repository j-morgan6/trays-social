import SwiftUI

/// Discovery insert card — surfaces inside the Feed between followed
/// recipes, clearly labeled so it never reads as an ad.
///
/// Mirrors the design's iOS Feed insert
/// (design/handoff/trays-social/project/ios-screens.jsx, IOSFeed).
struct DiscoveryInsert: View {
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14))
                .foregroundStyle(Theme.secondary)

            VStack(alignment: .leading, spacing: 2) {
                Text("FROM FIND · ADJACENT TO YOUR SAVES")
                    .font(.system(size: 9, weight: .medium, design: .monospaced))
                    .foregroundStyle(Theme.secondary)
                    .tracking(1.5)

                Text("Two suggestions interleaved — never an ad.")
                    .font(.system(size: 12))
                    .foregroundStyle(Theme.text)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Theme.secondary.opacity(0.1))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Theme.secondary.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
