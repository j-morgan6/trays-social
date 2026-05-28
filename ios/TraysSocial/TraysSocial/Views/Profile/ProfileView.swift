import OSLog
import PhotosUI
import SwiftUI

private let profileLog = Logger(subsystem: "com.trays.social", category: "profile")

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
            // D77: pre-fill from the profile grid's already-loaded Post.
            PostDetailView(postId: post.id, initialPost: post.user.id == 0 ? nil : post)
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
            SettingsView(onEditProfile: { showEditProfile = true })
        }
        .sheet(isPresented: $showReportUser) {
            if let user = viewModel.user {
                ReportSheetView(targetType: "user", targetId: user.id)
            }
        }
        .toolbar {
            if viewModel.isOwnProfile, viewModel.user != nil {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.gray)
                    }
                    .accessibilityLabel("Settings")
                }
            } else if !viewModel.isOwnProfile, viewModel.user != nil {
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
            } catch {
                // D95: write-path failure — log + toast. User-initiated.
                profileLog.error("blockUser failed: \(String(describing: error), privacy: .public)")
                ErrorReporter.report(error, fallback: "Couldn't block @\(username).")
            }
        }
    }

    /// Profile body ported from the Pass 1 prototype's ProfileScreen
    /// (prototype.jsx lines 697-757): centered 84pt avatar with a 1pt
    /// border ring, 24pt bold name, amber-handle, centered bio, three
    /// stats (Recipes / Following / Followers in that order), and a
    /// Follow button on other-user profiles. D88: own-profile actions
    /// (Edit profile, Drafts, Settings, Sign out) moved from an inline
    /// card to the gear toolbar item → SettingsView.
    private func editorialProfileBody(_ user: User) -> some View {
        ProfileBody(
            user: user,
            posts: viewModel.posts,
            isOwnProfile: viewModel.isOwnProfile,
            isFollowing: user.followedByCurrentUser == true,
            onToggleFollow: { viewModel.toggleFollow() }
        )
    }
}

/// Body of the Profile screen — centered avatar, name, amber handle,
/// bio, three stats, and either a sectioned action list (own profile)
/// or a Follow / Following button (other profile). Lifted into its own
/// struct so ProfileView stays readable.
private struct ProfileBody: View {
    @Environment(\.colorScheme) private var colorScheme
    let user: User
    let posts: [Post]
    let isOwnProfile: Bool
    let isFollowing: Bool
    let onToggleFollow: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            avatar
                .padding(.top, 14)
                .padding(.bottom, 14)

            Text(displayName)
                .font(.system(size: 24, weight: .bold))
                .tracking(-0.48)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 20)

            Text("@\(user.username)")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Theme.accentInk(for: colorScheme))
                .lineLimit(1)
                .truncationMode(.tail)
                .padding(.top, 6)
                .padding(.horizontal, 20)

            if let bio = user.bio, !bio.isEmpty {
                Text(bio)
                    .font(.system(size: 13.5))
                    .lineSpacing(3)
                    .foregroundStyle(Theme.muted(for: colorScheme))
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 280)
                    .padding(.top, 10)
            }

            statsRow
                .padding(.top, 18)
                .padding(.bottom, 14)

            if !isOwnProfile {
                followButton
                    .padding(.top, 8)
            }

            postsGrid
                .padding(.top, 24)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 110)
    }

    /// D74: restore the per-profile posts grid that W138's Pass 1
    /// prototype port had dropped. The prototype showed only the
    /// stats triplet and action list — but a recipe app's profile
    /// without the cook's posts feels broken. 2-col grid of GridCard
    /// (the W134 primitive) tapping into PostDetailView.
    @ViewBuilder
    private var postsGrid: some View {
        if posts.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                SectionHeader(label: "Recipes", count: posts.count)
                LazyVGrid(
                    columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())],
                    spacing: 10
                ) {
                    ForEach(posts) { post in
                        NavigationLink(value: post) {
                            GridCard(
                                photoKey: photoKey(for: post),
                                title: gridTitle(for: post),
                                url: post.primaryPhotoURL?.asBackendURL
                            )
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }
        }
    }

    private func photoKey(for post: Post) -> FoodPalette.Key {
        let keys = FoodPalette.Key.allCases
        return keys[abs(post.id) % keys.count]
    }

    private func gridTitle(for post: Post) -> String {
        let raw = (post.caption ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return "Untitled" }
        let candidate = raw.components(separatedBy: CharacterSet(charactersIn: ".!?\n"))
            .first?
            .trimmingCharacters(in: .whitespaces) ?? raw
        return candidate.isEmpty ? "Untitled" : candidate
    }

    private var avatar: some View {
        Group {
            if let urlString = user.profilePhotoUrl, let imageURL = urlString.asBackendURL {
                CachedAsyncImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray4))
                }
                .frame(width: 84, height: 84)
                .clipShape(Circle())
                .overlay(
                    Circle().inset(by: 0.5).stroke(borderColor, lineWidth: 1)
                )
                .id(imageURL)
            } else {
                Avi(
                    initial: String(user.username.prefix(1)),
                    size: 84,
                    palette: avatarPalette,
                    border: true
                )
            }
        }
    }

    private var borderColor: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.18)
            : Color.black.opacity(0.10)
    }

    private var avatarPalette: Avi.Palette {
        let palettes = Avi.Palette.allCases
        return palettes[abs(user.id) % palettes.count]
    }

    private var displayName: String {
        // The User model exposes the username; the prototype shows a
        // display name. Until we add a display-name field, surface the
        // username as the visual heading and the handle below it.
        user.username
    }

    private var statsRow: some View {
        HStack(spacing: 22) {
            statCell(value: user.postCount ?? 0, label: "Recipes")
            NavigationLink(value: FollowListRoute(username: user.username, mode: .following)) {
                statCell(value: user.followingCount ?? 0, label: "Following")
            }
            .buttonStyle(.borderless)
            NavigationLink(value: FollowListRoute(username: user.username, mode: .followers)) {
                statCell(value: user.followerCount ?? 0, label: "Followers")
            }
            .buttonStyle(.borderless)
        }
    }

    private func statCell(value: Int, label: String) -> some View {
        VStack(spacing: 4) {
            Text("\(value)")
                .font(.system(size: 22, weight: .semibold))
                .tracking(-0.44)
                .foregroundStyle(colorScheme == .dark ? Theme.textDark : Theme.textLight)
            Text(label.uppercased())
                .font(.system(size: 11, weight: .medium))
                .tracking(0.66)
                .foregroundStyle(Theme.muted(for: colorScheme))
        }
        .accessibilityElement(children: .combine)
    }

    private var followButton: some View {
        Button(action: onToggleFollow) {
            Text(isFollowing ? "Following" : "Follow @\(user.username)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isFollowing ? (colorScheme == .dark ? Theme.textDark : Theme.textLight) : Theme.inkOnAccent)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(
                    Capsule(style: .continuous)
                        .fill(isFollowing ? Theme.surface : Theme.accent)
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Theme.hairline(for: colorScheme), lineWidth: isFollowing ? 1 : 0)
                )
        }
        .buttonStyle(.plain)
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
                    CachedAsyncImage(url: imageURL) { image in
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
            // W113: avoid showing raw error.localizedDescription per the
            // pitfall list — route the error through the shared mapper so
            // network blips read "Couldn't load — check your connection."
            // instead of Cocoa's "The operation couldn't be completed..."
            errorMessage = ErrorReporter.userMessage(for: error, fallback: "Couldn't save your profile.")
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
    @State private var showAdminIosCrashes = false
    @State private var showAdminFeedback = false
    @State private var showSendFeedback = false
    @AppStorage("colorScheme") private var colorSchemePreference = "system"

    /// Fired when the user taps "Edit profile". The parent (ProfileView)
    /// is the natural owner of the EditProfileView sheet because it
    /// needs to re-fetch the profile on save (username changes are part
    /// of the route key). SettingsView dismisses itself before invoking
    /// the callback so the two sheet transitions don't compete.
    var onEditProfile: (() -> Void)?

    var body: some View {
        NavigationStack {
            List {
                Section("Account") {
                    Button {
                        dismiss()
                        onEditProfile?()
                    } label: {
                        HStack {
                            Text("Edit profile")
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    .foregroundStyle(Theme.text)

                    // Drafts: placeholder row, no destination yet. Kept
                    // discoverable so a future drafts list lands in the
                    // expected place without a layout shuffle.
                    HStack {
                        Text("Your drafts")
                            .foregroundStyle(Theme.text.opacity(0.5))
                        Spacer()
                        Text("Coming soon")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

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

                Section("Feedback") {
                    Button {
                        showSendFeedback = true
                    } label: {
                        HStack {
                            Text("Send Feedback")
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

                        Button {
                            showAdminIosCrashes = true
                        } label: {
                            HStack {
                                Text("iOS Crashes")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .foregroundStyle(Theme.text)

                        Button {
                            showAdminFeedback = true
                        } label: {
                            HStack {
                                Text("Feedback")
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
            // Legal sheets — URL is built from the current build's API base
            // so a Debug install opens the review env's pages and a Release
            // install opens prod's, matching the admin-sheets pattern below.
            // The point: when iterating on Privacy / Terms / Community
            // Guidelines copy, a TestFlight reviewer on the Debug build can
            // verify the new wording on review.trays.app before it ships to
            // prod. Previously these three URLs were hardcoded to
            // https://trays.app/<path> while the admin sheets routed through
            // Configuration.apiBaseURL — the mixed strategy was the actual
            // D68 bug. See the ios_env_routing_gotchas memory; env routing
            // has bitten this project before (the build-15 Apple Sign In
            // double-encode incident is the cautionary tale).
            .sheet(isPresented: $showPrivacy) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/privacy")!)
            }
            .sheet(isPresented: $showCommunityGuidelines) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/community-guidelines")!)
            }
            .sheet(isPresented: $showTerms) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/terms")!)
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
            .sheet(isPresented: $showAdminIosCrashes) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/ios-crashes")!)
            }
            .sheet(isPresented: $showAdminFeedback) {
                SafariView(url: URL(string: Configuration.apiBaseURL + "/admin/feedback")!)
            }
            .sheet(isPresented: $showSendFeedback) {
                FeedbackView()
            }
        }
    }
}
