import PhotosUI
import SwiftUI

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
            return String(localized: "Username must be 3–30 characters")
        }
        guard trimmed.range(of: #"^[a-zA-Z0-9_]+$"#, options: .regularExpression) != nil else {
            return String(localized: "Username can only contain letters, numbers, and underscores")
        }
        guard bio.count <= 500 else {
            return String(localized: "Bio must be 500 characters or less")
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
            errorMessage = ErrorReporter.userMessage(
                for: error,
                fallback: String(localized: "Couldn't save your profile.")
            )
            isSaving = false
        }
    }
}
