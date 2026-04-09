import SwiftUI

struct MainView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        VStack(spacing: 0) {
            // Top bar
            HStack {
                Text("Trays")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)

                Spacer()

                // Bell icon placeholder
                Button(action: {}) {
                    Image(systemName: "bell")
                        .foregroundStyle(.gray)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            // Tray selector placeholder
            Text("Tray navigation built in W64")
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Bottom bar placeholder
            HStack {
                Spacer()
                Text("Bottom bar built in W64")
                    .foregroundStyle(.secondary)
                Spacer()
            }
            .padding(.vertical, 12)
            .background(.black)
        }
        .background(.black)
    }
}
