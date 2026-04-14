import SwiftUI

struct TraySelector: View {
    @Binding var selectedTray: AppState.TrayTab
    @Namespace private var indicatorNamespace

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppState.TrayTab.allCases, id: \.rawValue) { tray in
                Button {
                    withAnimation(.easeInOut(duration: 0.25)) {
                        selectedTray = tray
                    }
                } label: {
                    Text(tray.label)
                        .font(.subheadline.weight(selectedTray == tray ? .semibold : .regular))
                        .foregroundStyle(selectedTray == tray ? Theme.primary : Color(.systemGray))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                }
                .buttonStyle(.plain)
                .background {
                    if selectedTray == tray {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Theme.surface)
                            .matchedGeometryEffect(id: "activeTab", in: indicatorNamespace)
                    }
                }
            }
        }
        .animation(.easeInOut(duration: 0.25), value: selectedTray)
        .padding(3)
        .background(Theme.surface)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Theme.surface, lineWidth: 1)
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
