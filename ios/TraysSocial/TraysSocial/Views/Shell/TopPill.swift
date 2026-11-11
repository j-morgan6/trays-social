import SwiftUI

/// Top of the nav shell (W239, redesign canvas): a floating pill holding
/// the three tab segments of `layout` (Home / My Tray / Search when
/// recipe-first, Feed / My Tray / Find otherwise) and, on the right, a
/// separate round pill for the bell with an amber unread dot. The canvas
/// drops the "Trays" wordmark from the iOS top bar.
struct TopPill: View {
    @Binding var selectedTray: AppState.TrayTab
    var layout: ShellLayout = .classic
    var hasUnread: Bool = false
    var unreadCount: Int = 0
    var onBellTap: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            PillBar {
                ForEach(layout.tabs, id: \.self) { tray in
                    tabSegment(for: tray, label: tray.label)
                }
            }
            Spacer(minLength: 8)
            PillBar(horizontalPadding: 0, verticalPadding: 0) {
                bellButton
            }
        }
        .frame(height: 56)
        // The shell is fixed chrome: past xxxLarge the three tabs and the bell no longer fit
        // a 375pt row, so larger sizes read the labels through the large content viewer.
        .dynamicTypeSize(...DynamicTypeSize.xxxLarge)
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
                .frame(width: 46, height: 46)
                .overlay(alignment: .topTrailing) {
                    if hasUnread {
                        Circle()
                            .fill(Theme.accent)
                            .frame(width: 9, height: 9)
                            .padding(2)
                            .background(Circle().fill(Theme.surface))
                            .padding(7)
                    }
                }
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(bellAccessibilityLabel)
        .accessibilityShowsLargeContentViewer()
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

#Preview("TopPill · light") {
    TopPill(selectedTray: .constant(.home), layout: .recipeFirst, hasUnread: true) {}
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.light)
}

#Preview("TopPill · dark") {
    TopPill(selectedTray: .constant(.home), layout: .recipeFirst, hasUnread: true) {}
        .padding()
        .background(Theme.background)
        .preferredColorScheme(.dark)
}

#Preview("TopPill · largest text") {
    TopPill(selectedTray: .constant(.home), layout: .recipeFirst, hasUnread: true) {}
        .padding()
        .background(Theme.background)
        .dynamicTypeSize(.accessibility5)
}
