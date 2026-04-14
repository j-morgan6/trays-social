import SwiftUI

struct BlockedUsersView: View {
    @State private var blockedUsers: [BlockedUser] = []
    @State private var isLoading = true

    struct BlockedUser: Codable, Identifiable {
        let id: Int
        let username: String
        let profilePhotoUrl: String?
    }

    var body: some View {
        List {
            ForEach(blockedUsers) { user in
                HStack {
                    Circle()
                        .fill(Color(.systemGray4))
                        .frame(width: 36, height: 36)
                        .overlay {
                            if let url = user.profilePhotoUrl, let imageURL = url.asBackendURL {
                                AsyncImage(url: imageURL) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: { Color.clear }
                                .frame(width: 36, height: 36)
                                .clipShape(Circle())
                            } else {
                                Image(systemName: "person.fill")
                                    .foregroundStyle(.gray)
                            }
                        }

                    Text(user.username)
                        .font(.subheadline)
                        .foregroundStyle(Theme.text)

                    Spacer()

                    Button("Unblock") {
                        Task { await unblock(user) }
                    }
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.red)
                }
            }
        }
        .listStyle(.plain)
        .background(Theme.background)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isLoading {
                ProgressView().tint(Theme.accent)
            } else if blockedUsers.isEmpty {
                Text("No blocked users")
                    .foregroundStyle(.secondary)
            }
        }
        .task { await loadBlocked() }
    }

    private func loadBlocked() async {
        do {
            let response: DataResponse<[BlockedUser]> = try await APIClient.shared.get(path: "/blocked-users")
            blockedUsers = response.data
        } catch { }
        isLoading = false
    }

    private func unblock(_ user: BlockedUser) async {
        do {
            let _: MessageResponse = try await APIClient.shared.delete(path: "/users/\(user.username)/block")
            blockedUsers.removeAll { $0.id == user.id }
        } catch { }
    }
}
