import SwiftUI

/// Transient top-of-screen error banner. Reads `AppState.currentError`
/// and slides in from the top safe-area edge. Tap anywhere to dismiss
/// early; otherwise it auto-clears after ~3s (the timer lives on
/// `AppState`, not here, so rapid `showError` calls cleanly reset).
///
/// Mount once at the app root in `TraysSocialApp` via `.overlay()` so
/// it sits above every screen. The current root-level overlay does
/// NOT layer above modally-presented sheets — flows that own a sheet
/// should surface errors inline (see `ReportSheetView` for the
/// pattern). Tradeoff documented in W113.
struct ErrorToast: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack {
            if let message = appState.currentError {
                banner(message: message)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onReceive(
                        NotificationCenter.default.publisher(for: .traysErrorOccurred)
                    ) { _ in
                        // No-op: AppState already heard the notification
                        // and updated currentError. The body is rebuilt
                        // because `message` changed. This handler exists
                        // only to keep the publisher subscribed.
                    }
            }
            Spacer(minLength: 0)
        }
        .animation(.easeInOut(duration: 0.22), value: appState.currentError)
        .allowsHitTesting(appState.currentError != nil)
    }

    private func banner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(Theme.accent)

            Text(message)
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isStaticText)

            Spacer(minLength: 0)

            Button {
                appState.dismissCurrentError()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.subtle(for: colorScheme))
                    .padding(4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Dismiss error")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Theme.hairline(for: colorScheme), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.12), radius: 12, y: 6)
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .contentShape(Rectangle())
        .onTapGesture {
            appState.dismissCurrentError()
        }
        .accessibilityElement(children: .combine)
        .accessibilityHint("Tap to dismiss")
    }
}
