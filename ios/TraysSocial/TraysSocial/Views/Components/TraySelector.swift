import SwiftUI

struct TraySelector: View {
    @Binding var selectedTray: AppState.TrayTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.TrayTab.allCases, id: \.rawValue) { tray in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTray = tray
                    }
                } label: {
                    Text(tray.label)
                        .font(.subheadline.weight(selectedTray == tray ? .semibold : .regular))
                        .foregroundStyle(selectedTray == tray ? Theme.accent : Color(.systemGray))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTray == tray
                                ? Color.white.opacity(0.08)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }
}

extension AppState.TrayTab {
    var label: String {
        switch self {
        case .feed: "Feed"
        case .find: "Find"
        case .myTray: "My Tray"
        }
    }
}
