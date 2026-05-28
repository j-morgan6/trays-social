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
        Group {
            if isLoading, blockedUsers.isEmpty {
                ScrollView {
                    VStack(spacing: 6) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            SkeletonListRow()
                        }
                    }
                    .padding(.top, 12)
                }
                .skeletonGroup(label: "Loading blocked users")
            } else if blockedUsers.isEmpty {
                EditorialEmptyState(
                    title: "No one blocked.",
                    subtitle: "Block someone from their profile and they'll show up here."
                )
            } else {
                List {
                    ForEach(blockedUsers) { user in
                        blockedRow(user)
                    }
                }
                .listStyle(.plain)
            }
        }
        .background(Theme.background)
        .navigationTitle("Blocked Users")
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadBlocked() }
    }

    private func blockedRow(_ user: BlockedUser) -> some View {
        HStack {
            Circle()
                .fill(Color(.systemGray4))
                .frame(width: 36, height: 36)
                .overlay {
                    if let url = user.profilePhotoUrl, let imageURL = url.asBackendURL {
                        CachedAsyncImage(url: imageURL) { image in
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
                .lineLimit(1)
                .truncationMode(.tail)

            Spacer(minLength: 8)

            Button("Unblock") {
                Task { await unblock(user) }
            }
            .font(.caption.weight(.medium))
            .foregroundStyle(.red)
        }
    }

    private func loadBlocked() async {
        do {
            let response: DataResponse<[BlockedUser]> = try await APIClient.shared.get(path: "/blocked-users")
            blockedUsers = response.data
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't load blocked users.")
        }
        isLoading = false
    }

    private func unblock(_ user: BlockedUser) async {
        do {
            let _: MessageResponse = try await APIClient.shared.delete(path: "/users/\(user.username)/block")
            blockedUsers.removeAll { $0.id == user.id }
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't unblock \(user.username).")
        }
    }
}
