import SwiftUI

/// Top floating pill in the nav shell. Hosts the Trays wordmark, the
/// three Feed / My Tray / Find tab segments, and the bell button with
/// an unread indicator.
///
/// Below the 380pt-width threshold (iPhone SE class devices in
/// portrait), the wordmark hides so the three segments + bell still
/// fit on a single row without truncating.
struct TopPill: View {
    @Binding var selectedTray: AppState.TrayTab
    var hasUnread: Bool = false
    var unreadCount: Int = 0
    var onBellTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let showWordmark = proxy.size.width >= 380
            PillBar {
                if showWordmark {
                    Text("Trays")
                        .font(.serif(15))
                        .foregroundStyle(Theme.accent)
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                }
                tabSegment(for: .feed, label: "Feed")
                tabSegment(for: .myTray, label: "My Tray")
                tabSegment(for: .find, label: "Find")
                bellButton
            }
        }
        .frame(height: 56)
    }

    private func tabSegment(for tray: AppState.TrayTab, label: String) -> some View {
        TabSegment(label: label, isActive: selectedTray == tray) {
            withAnimation(.easeInOut(duration: 0.18)) {
                selectedTray = tray
            }
        }
    }

    private var bellButton: some View {
        Button(action: onBellTap) {
            Image(systemName: "bell")
                .font(.system(size: 17, weight: .regular))
                .foregroundStyle(Theme.text)
                .frame(width: 36, height: 36)
                .overlay(alignment: .topTrailing) {
                    if hasUnread {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 7, height: 7)
                            .offset(x: -6, y: 6)
                    }
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bellAccessibilityLabel)
    }

    private var bellAccessibilityLabel: String {
        if hasUnread {
            return unreadCount > 0
                ? "Notifications, \(unreadCount) unread"
                : "Notifications, unread"
        }
        return "Notifications"
    }
}
