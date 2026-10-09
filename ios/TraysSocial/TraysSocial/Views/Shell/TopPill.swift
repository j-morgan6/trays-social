import SwiftUI

/// Top floating pill in the nav shell. Hosts the Trays wordmark, the
/// three tab segments of `layout` (Feed / My Tray / Find, or Home /
/// My Tray / Search when recipe-first), and the bell button with an
/// unread indicator.
///
/// Below the 380pt-width threshold (iPhone SE class devices in
/// portrait), the wordmark hides so the three segments + bell still
/// fit on a single row without truncating.
struct TopPill: View {
    @Binding var selectedTray: AppState.TrayTab
    var layout: ShellLayout = .classic
    var hasUnread: Bool = false
    var unreadCount: Int = 0
    var onBellTap: () -> Void

    var body: some View {
        GeometryReader { proxy in
            let showWordmark = proxy.size.width >= 380
            PillBar {
                if showWordmark {
                    Text("Trays")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                        .padding(.leading, 4)
                        .padding(.trailing, 4)
                }
                ForEach(layout.tabs, id: \.self) { tray in
                    tabSegment(for: tray, label: tray.label)
                }
                bellButton
            }
        }
        .frame(height: 56)
    }

    private func tabSegment(for tray: AppState.TrayTab, label: LocalizedStringKey) -> some View {
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
                ? String(localized: "Notifications, \(unreadCount) unread")
                : String(localized: "Notifications, unread")
        }
        return String(localized: "Notifications")
    }
}
