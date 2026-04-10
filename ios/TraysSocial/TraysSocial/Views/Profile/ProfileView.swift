import SwiftUI

struct ProfileView: View {
    let username: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(.orange).padding(.top, 60)
            } else if let user = viewModel.user {
                VStack(spacing: 20) {
                    // Avatar + Name
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 80, height: 80)
                            .overlay {
                                if let url = user.profilePhotoUrl, let imageURL = URL(string: url) {
                                    AsyncImage(url: imageURL) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: { Color.clear }
                                    .frame(width: 80, height: 80)
                                    .clipShape(Circle())
                                } else {
                                    Image(systemName: "person.fill")
                                        .font(.title)
                                        .foregroundStyle(.gray)
                                }
                            }

                        Text(user.username)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(.white)

                        if let bio = user.bio, !bio.isEmpty {
                            Text(bio)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }

                    // Stats
                    HStack(spacing: 16) {
                        statBox(value: user.postCount ?? 0, label: "Recipes")
                        statBox(value: user.followerCount ?? 0, label: "Followers")
                        statBox(value: user.followingCount ?? 0, label: "Following")
                    }

                    // Action button
                    if viewModel.isOwnProfile {
                        HStack(spacing: 12) {
                            Button("Edit Profile") { showEditProfile = true }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .foregroundStyle(.gray)
                                    .padding(10)
                                    .background(Color.white.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }
                        .padding(.horizontal, 16)
                    } else {
                        Button {
                            viewModel.toggleFollow()
                        } label: {
                            Text(user.followedByCurrentUser == true ? "Following" : "Follow")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(user.followedByCurrentUser == true ? Color.white.opacity(0.1) : .orange)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                    }

                    // Posts grid
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 4) {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(value: post) {
                                if let url = post.primaryPhotoURL {
                                    AsyncImage(url: fullURL(url)) { image in
                                        image.resizable().scaledToFill()
                                    } placeholder: {
                                        Rectangle().fill(Color(.systemGray5))
                                    }
                                    .frame(height: 160)
                                    .clipped()
                                } else {
                                    Rectangle().fill(Color(.systemGray5))
                                        .frame(height: 160)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                }
                .padding(.top, 16)
            }
        }
        .background(.black)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(username: username, currentUserId: appState.currentUser?.id)
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    private func statBox(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(.white)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func fullURL(_ path: String) -> URL? {
        if path.hasPrefix("http") { return URL(string: path) }
        return URL(string: Configuration.apiBaseURL + path)
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var bio = ""
    @State private var isSaving = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                TextField("Username", text: $username)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                TextField("Bio", text: $bio, axis: .vertical)
                    .lineLimit(3...6)
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 12))

                Spacer()
            }
            .padding(16)
            .background(.black)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        Task {
                            isSaving = true
                            _ = try? await AuthService.updateUsername(username)
                            isSaving = false
                            dismiss()
                        }
                    }
                    .disabled(isSaving)
                }
            }
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false

    var body: some View {
        NavigationStack {
            List {
                Button("Log out") {
                    appState.logout()
                    dismiss()
                }
                .foregroundStyle(.white)

                Button("Delete account") {
                    showDeleteConfirm = true
                }
                .foregroundStyle(.red)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(.black)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .alert("Delete Account", isPresented: $showDeleteConfirm) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) {
                    Task {
                        _ = try? await APIClient.shared.delete(path: "/auth/me") as EmptyResponse
                        appState.handleUnauthorized()
                        dismiss()
                    }
                }
            } message: {
                Text("This will permanently delete your account and all your data. This cannot be undone.")
            }
        }
    }
}
