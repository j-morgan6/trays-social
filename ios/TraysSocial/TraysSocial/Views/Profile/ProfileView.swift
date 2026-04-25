import PhotosUI
import SwiftUI

struct ProfileView: View {
    let username: String
    @Environment(AppState.self) private var appState
    @State private var viewModel = ProfileViewModel()
    @State private var showEditProfile = false
    @State private var showSettings = false
    @State private var showReportUser = false
    @State private var showBlockConfirm = false

    var body: some View {
        ScrollView {
            if viewModel.isLoading {
                ProgressView().tint(Theme.accent).padding(.top, 60)
            } else if let user = viewModel.user {
                VStack(spacing: 20) {
                    // Avatar + Name
                    VStack(spacing: 8) {
                        Circle()
                            .fill(Color(.systemGray4))
                            .frame(width: 80, height: 80)
                            .overlay {
                                if let url = user.profilePhotoUrl, let imageURL = url.asBackendURL {
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
                            .foregroundStyle(Theme.text)

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
                        NavigationLink(value: FollowListRoute(username: user.username, mode: .followers)) {
                            statBox(value: user.followerCount ?? 0, label: "Followers")
                        }
                        .buttonStyle(.plain)
                        NavigationLink(value: FollowListRoute(username: user.username, mode: .following)) {
                            statBox(value: user.followingCount ?? 0, label: "Following")
                        }
                        .buttonStyle(.plain)
                    }

                    // Action button
                    if viewModel.isOwnProfile {
                        HStack(spacing: 12) {
                            Button("Edit Profile") { showEditProfile = true }
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(Theme.text)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Theme.surface)
                                .clipShape(RoundedRectangle(cornerRadius: 10))

                            Button { showSettings = true } label: {
                                Image(systemName: "gearshape")
                                    .foregroundStyle(.gray)
                                    .padding(10)
                                    .background(Theme.surface)
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
                                .background(user.followedByCurrentUser == true ? Theme.surface : Theme.primary)
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .padding(.horizontal, 16)
                    }

                    // Content filter
                    Picker("Filter", selection: Bindable(viewModel).filter) {
                        Text("All").tag("all")
                        Text("Posts").tag("posts")
                        Text("Recipes").tag("recipes")
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .onChange(of: viewModel.filter) {
                        Task {
                            if let user = viewModel.user {
                                await viewModel.loadPosts(username: user.username)
                            }
                        }
                    }

                    // Posts grid
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 4) {
                        ForEach(viewModel.posts) { post in
                            NavigationLink(value: post) {
                                if let url = post.primaryPhotoURL {
                                    AsyncImage(url: url.asBackendURL) { image in
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
        .background(Theme.background)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await viewModel.loadProfile(username: username, currentUserId: appState.currentUser?.id)
        }
        .navigationDestination(for: Post.self) { post in
            PostDetailView(postId: post.id)
        }
        .sheet(isPresented: $showEditProfile) {
            EditProfileView { updatedUser in
                // Re-fetch so stats stay accurate and the (possibly new) username is used.
                Task {
                    await viewModel.loadProfile(
                        username: updatedUser.username,
                        currentUserId: appState.currentUser?.id
                    )
                }
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .sheet(isPresented: $showReportUser) {
            if let user = viewModel.user {
                ReportSheetView(targetType: "user", targetId: user.id)
            }
        }
        .toolbar {
            if !viewModel.isOwnProfile, viewModel.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        Button("Block User", role: .destructive) {
                            if let user = viewModel.user {
                                blockUser(user.username)
                            }
                        }
                        Button("Report User", role: .destructive) {
                            showReportUser = true
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .foregroundStyle(.gray)
                    }
                }
            }
        }
    }

    private func blockUser(_ username: String) {
        Task {
            do {
                let _: MessageResponse = try await APIClient.shared.post(path: "/users/\(username)/block")
                // Pop back to previous screen
            } catch {}
        }
    }

    private func statBox(value: Int, label: String) -> some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.headline)
                .foregroundStyle(Theme.primary)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Theme.secondary.opacity(0.25))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

// MARK: - Edit Profile

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    var onSave: ((User) -> Void)?

    @State private var username = ""
    @State private var bio = ""
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var newPhotoData: Data?
    @State private var newPhotoImage: Image?
    @State private var isSaving = false
    @State private var errorMessage: String?
    @State private var didPopulate = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    avatarSection

                    VStack(alignment: .leading, spacing: 6) {
                        Text("USERNAME")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.gray)
                            .tracking(0.5)
                        TextField("username", text: $username)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .padding(12)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        Text("BIO")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.gray)
                            .tracking(0.5)
                        TextField("Tell people about yourself", text: $bio, axis: .vertical)
                            .lineLimit(3 ... 6)
                            .padding(12)
                            .background(Theme.surface)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                        Text("\(bio.count)/500")
                            .font(.caption2)
                            .foregroundStyle(bio.count > 500 ? .red : Color(.systemGray2))
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding(16)
            }
            .background(Theme.background)
            .navigationTitle("Edit Profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                        .disabled(isSaving)
                }
                ToolbarItem(placement: .confirmationAction) {
                    if isSaving {
                        ProgressView().tint(Theme.accent)
                    } else {
                        Button("Save") {
                            Task { await save() }
                        }
                    }
                }
            }
            .onAppear {
                // Pre-populate once so in-progress edits aren't clobbered by re-renders.
                guard !didPopulate, let user = appState.currentUser else { return }
                username = user.username
                bio = user.bio ?? ""
                didPopulate = true
            }
            .onChange(of: selectedPhoto) {
                Task { await loadSelectedPhoto() }
            }
        }
    }

    // MARK: - Avatar

    private var avatarSection: some View {
        VStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(Color(.systemGray5))
                    .frame(width: 100, height: 100)

                if let newPhotoImage {
                    newPhotoImage
                        .resizable()
                        .scaledToFill()
                        .frame(width: 100, height: 100)
                        .clipShape(Circle())
                } else if let urlString = appState.currentUser?.profilePhotoUrl,
                          let imageURL = urlString.asBackendURL
                {
                    AsyncImage(url: imageURL) { image in
                        image.resizable().scaledToFill()
                    } placeholder: {
                        Image(systemName: "person.fill")
                            .font(.title)
                            .foregroundStyle(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                } else {
                    Image(systemName: "person.fill")
                        .font(.title)
                        .foregroundStyle(.gray)
                }
            }

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Change Photo")
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(Theme.accent)
            }
            .disabled(isSaving)
        }
        .padding(.top, 12)
    }

    // MARK: - Logic

    private func loadSelectedPhoto() async {
        guard let item = selectedPhoto else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            newPhotoData = data
            if let uiImage = UIImage(data: data) {
                newPhotoImage = Image(uiImage: uiImage)
            }
        }
    }

    private func validate() -> String? {
        let trimmed = username.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 3, trimmed.count <= 30 else {
            return "Username must be 3–30 characters"
        }
        guard trimmed.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil else {
            return "Username can only contain letters, numbers, and underscores"
        }
        guard bio.count <= 500 else {
            return "Bio must be 500 characters or less"
        }
        return nil
    }

    private func save() async {
        if let error = validate() {
            errorMessage = error
            return
        }

        isSaving = true
        errorMessage = nil

        do {
            // If the user picked a new photo, upload it first and use the returned URL.
            // Otherwise keep the existing URL so the backend doesn't clear it.
            var photoUrl = appState.currentUser?.profilePhotoUrl
            if let newPhotoData {
                photoUrl = try await APIClient.shared.upload(
                    path: "/uploads",
                    imageData: newPhotoData,
                    filename: "avatar.jpg"
                )
            }

            let updatedUser = try await AuthService.updateProfile(
                username: username.trimmingCharacters(in: .whitespacesAndNewlines),
                bio: bio,
                profilePhotoUrl: photoUrl
            )

            appState.currentUser = updatedUser
            onSave?(updatedUser)
            isSaving = false
            dismiss()
        } catch {
            errorMessage = "Failed to save: \(error.localizedDescription)"
            isSaving = false
        }
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    @State private var showDeleteConfirm = false
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    var body: some View {
        NavigationStack {
            List {
                Section("Appearance") {
                    Picker("Mode", selection: $colorSchemePreference) {
                        Text("System").tag("system")
                        Text("Light").tag("light")
                        Text("Dark").tag("dark")
                    }
                    .pickerStyle(.segmented)
                }

                Section("Content Filters") {
                    NavigationLink("Blocked Users") {
                        BlockedUsersView()
                    }
                    .foregroundStyle(Theme.text)

                    NavigationLink("Muted Keywords") {
                        MutedKeywordsView()
                    }
                    .foregroundStyle(Theme.text)
                }

                Section {
                    Button("Log out") {
                        appState.logout()
                        dismiss()
                    }
                    .foregroundStyle(Theme.text)

                    Button("Delete account") {
                        showDeleteConfirm = true
                    }
                    .foregroundStyle(.red)
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Theme.background)
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
