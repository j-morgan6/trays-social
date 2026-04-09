import SwiftUI

struct WelcomeView: View {
    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Text("Trays")
                .font(.system(size: 42, weight: .bold))
                .foregroundStyle(.white)

            Text("Find something to eat")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            // Placeholder — auth flows built in W63
            Text("Auth screens coming soon")
                .foregroundStyle(.secondary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.black)
    }
}
