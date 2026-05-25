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
                VStack(spacing: 20) {
                    SkeletonProfileHeader()
                    LazyVGrid(columns: [.init(.flexible()), .init(.flexible())], spacing: 8) {
                        ForEach(0 ..< 4, id: \.self) { _ in
                            SkeletonGridTile()
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .skeletonGroup(label: "Loading profile")
            } else if let user = viewModel.user {
                editorialProfileBody(user)
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

    /// Editorial profile body — matches IOSProfile from the Claude
    /// Design handoff. Avatar + serif display name + @handle, bio,
    /// stats row with serif numerals, Follow/Edit CTA, 3-up grid with
    /// serif title overlay.
    private func editorialProfileBody(_ user: User) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            // Hero row — avatar (80pt) inline with serif name + handle
            HStack(alignment: .center, spacing: 16) {
                profileAvatar(user)
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username)
                        .font(.serif(30))
                        .foregroundStyle(Theme.text)
                        .lineLimit(1)
                    Text("@\(user.username)")
                        .font(.system(size: 12))
                        .foregroundStyle(Theme.textSecondary)
                }
                Spacer(minLength: 0)
            }

            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 14))
                    .foregroundStyle(Theme.text)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Stats — serif numerals + muted labels
            HStack(spacing: 24) {
                statCell(value: user.postCount ?? 0, label: "recipes")
                NavigationLink(value: FollowListRoute(username: user.username, mode: .followers)) {
                    statCell(value: user.followerCount ?? 0, label: "followers")
                }
                .buttonStyle(.borderless)
                NavigationLink(value: FollowListRoute(username: user.username, mode: .following)) {
                    statCell(value: user.followingCount ?? 0, label: "following")
                }
                .buttonStyle(.borderless)
                Spacer(minLength: 0)
            }

            // Action row
            actionRow(user)
                .padding(.top, 4)

            // Tabs eyebrow — design uses Recipes/About; keep the
            // existing filter Picker but reframe as quiet section
            // headers so it's visibly the design's tab strip.
            Divider().background(Color.white.opacity(0.08))

            Picker("Filter", selection: Bindable(viewModel).filter) {
                Text("All").tag("all")
                Text("Posts").tag("posts")
                Text("Recipes").tag("recipes")
            }
            .pickerStyle(.segmented)
            .onChange(of: viewModel.filter) {
                Task {
                    if let user = viewModel.user {
                        await viewModel.loadPosts(username: user.username)
                    }
                }
            }

            // 3-up grid with serif title overlay (matches IOSProfile)
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 6), count: 3), spacing: 6) {
                ForEach(viewModel.posts) { post in
                    NavigationLink(value: post) {
                        gridTile(post)
                    }
                    .buttonStyle(.borderless)
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 110)
    }

    private func profileAvatar(_ user: User) -> some View {
        Group {
            if let url = user.profilePhotoUrl, let imageURL = url.asBackendURL {
                AsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Color(.systemGray4)
                }
                .frame(width: 80, height: 80)
                .clipShape(Circle())
                .id(imageURL)
            } else {
                Circle()
                    .fill(Theme.primary)
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(user.username.prefix(1)).uppercased())
                            .font(.serif(34))
                            .foregroundStyle(.white)
                    )
            }
        }
    }

    @ViewBuilder
    private func actionRow(_ user: User) -> some View {
        if viewModel.isOwnProfile {
            HStack(spacing: 10) {
                Button("Edit profile") { showEditProfile = true }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.text)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .background(Theme.surface)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .font(.system(size: 16))
                        .foregroundStyle(Theme.textSecondary)
                        .frame(width: 38, height: 38)
                        .background(Theme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.borderless)
            }
        } else {
            let following = user.followedByCurrentUser == true
            Button {
                viewModel.toggleFollow()
            } label: {
                Text(following ? "Following" : "Follow \(user.username)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(following ? Theme.text : .white)
                    .frame(maxWidth: .infinity, minHeight: 42)
                    .background(following ? Theme.surface : Theme.primaryLight)
                    .clipShape(RoundedRectangle(cornerRadius: 21))
            }
            .buttonStyle(.borderless)
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("\(value)")
                .font(.serif(18))
                .foregroundStyle(Theme.text)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(Theme.textSecondary)
        }
    }

    private func gridTile(_ post: Post) -> some View {
        ZStack(alignment: .bottomLeading) {
            if let url = post.primaryPhotoURL {
                AsyncImage(url: url.asBackendURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Rectangle().fill(Color(.systemGray5))
                }
                .frame(height: 116)
                .clipped()
            } else {
                Rectangle().fill(Color(.systemGray5)).frame(height: 116)
            }

            LinearGradient(
                colors: [.clear, .black.opacity(0.8)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 116)

            VStack(alignment: .leading, spacing: 2) {
                Text(gridTileTitle(post))
                    .font(.serif(12))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let time = post.cookingTimeMinutes {
                    Text("\(time) MIN")
                        .font(.system(size: 8, weight: .medium, design: .monospaced))
                        .tracking(1)
                        .foregroundStyle(.white.opacity(0.85))
                }
            }
            .padding(.horizontal, 8)
            .padding(.bottom, 6)
        }
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func gridTileTitle(_ post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Recipe" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Recipe" : candidate
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
    @State private var showPrivacy = false
    @State private var showTerms = false
    @State private var showCommunityGuidelines = false
    @State private var showAdminReports = false
    @State private var showAdminErrors = false
    @State private var showAdminDashboard = false
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

                Section("Legal") {
                    Button {
                        showPrivacy = true
                    } label: {
                        HStack {
                            Text("Privacy Policy")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(Theme.text)

                    Button {
                        showTerms = true
                    } label: {
                        HStack {
                            Text("Terms of Service")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(Theme.text)

                    Button {
                        showCommunityGuidelines = true
                    } label: {
                        HStack {
                            Text("Community Guidelines")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(Theme.text)
                }

                if appState.currentUser?.hasAdminAccess == true {
                    Section("Admin") {
                        Button {
                            showAdminReports = true
                        } label: {
                            HStack {
                                Text("Reports")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(Theme.text)

                        Button {
                            showAdminErrors = true
                        } label: {
                            HStack {
                                Text("Error Tracker")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(Theme.text)

                        Button {
                            showAdminDashboard = true
                        } label: {
                            HStack {
                                Text("System Dashboard")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(Theme.text)
                    }
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
            .sheet(isPresented: $showPrivacy) {
                SafariView(url: URL(string: "https://trays.app/privacy")!)
            }
            .sheet(isPresented: $showCommunityGuidelines) {
                SafariView(url: URL(string: "https://trays.app/community-guidelines")!)
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: URL(string: "https://trays.app/terms")!)
            }
            // Admin sheets — URL is built from the current build's API base so
            // a Debug install opens the review env's admin pages and a Release
            // install opens prod's. Pre-authenticated session cookie is set on
            // the same hostname so the Safari sheet inherits the admin user's
            // browser session if one exists. Otherwise the user gets the
            // login screen (the admin pages are gated by RequireAdmin).
            .sheet(isPresented: $showAdminReports) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/reports")!)
            }
            .sheet(isPresented: $showAdminErrors) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/errors")!)
            }
            .sheet(isPresented: $showAdminDashboard) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/dashboard")!)
            }
        }
    }
}
