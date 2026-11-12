import SwiftUI

// MARK: - Post unavailable surface

/// Inline failure surface shown when the initial post load throws.
/// Distinguishes between 404 ("post not available") and everything
/// else ("couldn't load — try again"). The view model logs the failure;
/// this never toasts (refresh failures are silent).
///
/// W247: restyled like My Tray's `TrayLoadErrorView` (lift disc, empty-state
/// block, Try again), plus Back, because the recipe screen hides the nav bar.
struct PostUnavailableSurface: View {
    let copy: PostLoadErrorCopy
    let onRetry: () -> Void
    let onBack: () -> Void

    init(error: Error, onRetry: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.init(copy: PostLoadErrorCopy.decide(error: error), onRetry: onRetry, onBack: onBack)
    }

    init(copy: PostLoadErrorCopy, onRetry: @escaping () -> Void, onBack: @escaping () -> Void) {
        self.copy = copy
        self.onRetry = onRetry
        self.onBack = onBack
    }

    var body: some View {
        VStack(spacing: 18) {
            Circle()
                .fill(Theme.lift)
                .frame(width: 64, height: 64)
                .overlay {
                    Image(systemName: copy.allowsRetry ? "wifi.slash" : "doc.questionmark")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(Theme.muted)
                }
                .accessibilityHidden(true)

            EmptyStateBlock(
                title: copy.title,
                subtitle: copy.subtitle,
                topPadding: 0,
                chrome: .plain,
                action: copy.allowsRetry
                    ? .init(title: String(localized: "Try again"), isPrimary: true, perform: onRetry)
                    : nil
            )

            Button(action: onBack) {
                Text("Back")
            }
            .buttonStyle(.traySecondary)
            .accessibilityLabel(Text("Back to previous screen"))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, HomeMetrics.inset)
        .background(Theme.background)
    }
}
