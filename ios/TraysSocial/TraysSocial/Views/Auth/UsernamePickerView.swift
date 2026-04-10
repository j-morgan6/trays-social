import SwiftUI

struct UsernamePickerView: View {
    @Environment(AppState.self) private var appState
    @Bindable var viewModel: AuthViewModel

    var body: some View {
        VStack(spacing: 24) {
            Text("Choose a username")
                .font(.title.bold())
                .foregroundStyle(.white)

            Text("This is how other cooks will find you on Trays.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 4) {
                TextField("Username", text: $viewModel.username)
                    .textContentType(.username)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .padding()
                    .background(Theme.surface)
                    .cornerRadius(12)

                if !viewModel.username.isEmpty && !viewModel.isUsernameValid {
                    Text("3-30 characters, letters, numbers, underscores only")
                        .font(.caption2)
                        .foregroundStyle(.red)
                }
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.red)
            }

            Button {
                Task { await viewModel.setUsername(appState: appState) }
            } label: {
                if viewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                } else {
                    Text("Continue")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                }
            }
            .background(viewModel.isUsernameValid ? Theme.primary : .gray.opacity(0.3))
            .cornerRadius(12)
            .disabled(!viewModel.isUsernameValid || viewModel.isLoading)

            Spacer()
        }
        .padding(24)
        .background(Theme.background)
        .interactiveDismissDisabled()
    }
}
