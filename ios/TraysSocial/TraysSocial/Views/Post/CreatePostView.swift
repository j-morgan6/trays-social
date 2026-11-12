import PhotosUI
import SwiftUI

/// The recipe editor (W249, Create artboard): one calm page, not a form. A
/// photo slot, the Basics card (name, a line about it, time and serves),
/// Ingredients, Steps and Tools cards, Tags, a Preview of the recipe as
/// others will see it, and a floating amber Post button that shows a
/// spinner while posting. Posting and its rules are the view model's,
/// unchanged. Post looks quiet until a name, an ingredient, a step and a
/// photo are in, but stays tappable; after a tap, each missing piece says
/// what it needs in place, in amber, never red.
struct CreatePostView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var viewModel: CreatePostViewModel
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var keyboardVisible = false
    @State private var showsPreview = false
    /// Set by the first Post tap; from then on each missing piece says so in place.
    @State private var attemptedPost = false
    @FocusState private var focus: EditorField?

    init(viewModel: CreatePostViewModel = CreatePostViewModel()) {
        _viewModel = State(initialValue: viewModel)
    }

    private var isRecipe: Bool {
        viewModel.postType == .recipe
    }

    private var readiness: EditorReadiness {
        EditorReadiness.of(viewModel)
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView {
                    editor
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 16)
                        .simultaneousGesture(
                            DragGesture(minimumDistance: 40)
                                .onEnded(handleTypeSwipe)
                        )
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.errorMessage) { _, message in
                    guard message != nil else { return }
                    withAnimation(reduceMotion ? nil : .easeInOut) {
                        proxy.scrollTo(viewModel.photoData == nil ? "photo" : "error", anchor: .center)
                    }
                }
            }
            .background(Theme.background)
            .safeAreaInset(edge: .bottom) {
                EditorActionBar(
                    title: isRecipe ? String(localized: "Post recipe") : String(localized: "Share post"),
                    busyLabel: String(localized: "Posting"),
                    isBusy: viewModel.isPublishing,
                    looksReady: readiness.isReady,
                    action: publish
                )
            }
            // W196: recipe-first posts only recipes. `initial: true` covers
            // appear; the change covers the flag flipping while Create is open.
            .onChange(of: FeatureFlags.shared.recipeFirst, initial: true) { _, recipeFirst in
                if recipeFirst {
                    viewModel.postType = .recipe
                }
            }
            .onChange(of: selectedPhoto) {
                viewModel.selectedPhoto = selectedPhoto
                Task { await viewModel.loadPhoto() }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { _ in
                keyboardVisible = true
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardVisible = false
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Theme.background, for: .navigationBar)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar { toolbarContent }
        }
        .tint(Theme.primary)
        .overlay {
            if showsPreview {
                RecipeDraftPreview(
                    draft: RecipeDraft.make(from: viewModel),
                    photo: viewModel.photoImage,
                    onBack: { setPreview(false) },
                    onPost: {
                        setPreview(false)
                        publish()
                    }
                )
                .transition(reduceMotion ? .opacity : .move(edge: .bottom))
            }
        }
    }

    /// What to flag in place: nothing until Post has been tapped once.
    private var missing: EditorReadiness {
        attemptedPost ? readiness : .nothingMissing
    }

    private var editor: some View {
        VStack(alignment: .leading, spacing: 14) {
            typePicker

            VStack(alignment: .leading, spacing: 8) {
                EditorPhotoSlot(
                    image: viewModel.photoImage,
                    selection: $selectedPhoto,
                    needsAttention: missing.needsPhoto
                )
                if missing.needsPhoto {
                    EditorAttentionNote(message: String(localized: "Add a photo to post."))
                }
            }
            .id("photo")

            RecipeBasicsCard(
                caption: $viewModel.caption,
                minutes: $viewModel.cookingTimeMinutes,
                servings: $viewModel.servings,
                showsRecipeFields: isRecipe,
                nameNeedsAttention: missing.needsName,
                focus: $focus
            )

            if isRecipe {
                IngredientsCard(viewModel: viewModel, needsAttention: missing.needsIngredient, focus: $focus)
                StepsCard(viewModel: viewModel, needsAttention: missing.needsStep, focus: $focus)
                ToolsCard(viewModel: viewModel, focus: $focus)
            }

            TagsCard(viewModel: viewModel, focus: $focus)

            // A missing photo is the view model's only own rule, and it says so
            // at the photo slot; anything else (upload or server) shows here.
            if let error = viewModel.errorMessage, viewModel.photoData != nil {
                EditorAttentionNote(message: error)
                    .id("error")
            }
        }
    }

    @ToolbarContentBuilder private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Cancel") { dismiss() }
                .scaledFont(16, weight: .medium, relativeTo: .body)
                .foregroundStyle(Theme.text)
        }
        ToolbarItem(placement: .principal) {
            Text(isRecipe ? String(localized: "New recipe") : String(localized: "New post"))
                .roundedFont(17, weight: .heavy, relativeTo: .headline)
                .foregroundStyle(Theme.text)
                .accessibilityAddTraits(.isHeader)
        }
        if isRecipe {
            ToolbarItem(placement: .topBarTrailing) {
                Button(String(localized: "Preview")) {
                    focus = nil
                    setPreview(true)
                }
                .scaledFont(16, weight: .semibold, relativeTo: .body)
                .foregroundStyle(Theme.primaryInk)
                .disabled(viewModel.isPublishing)
            }
        }
        ToolbarItemGroup(placement: .keyboard) {
            Spacer()
            Button(String(localized: "Done")) { focus = nil }
                .foregroundStyle(Theme.primaryInk)
        }
    }

    private func setPreview(_ shown: Bool) {
        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) {
            showsPreview = shown
        }
    }

    private func publish() {
        guard !viewModel.isPublishing else { return }
        focus = nil
        attemptedPost = true
        Task {
            if await viewModel.publish() {
                // W170: Feed and My Tray observe this to
                // refresh — their .task gates never refire
                // under the paging TabView, so a new post
                // was invisible until manual pull-to-refresh.
                NotificationCenter.default.post(name: .postCreated, object: nil)
                dismiss()
            }
        }
    }
}

// MARK: - Type selection (W196: hidden under recipe-first)

private extension CreatePostView {
    /// Type switch — also swipe horizontally on the form to toggle. Hidden
    /// when recipe-first leaves a single type to choose.
    @ViewBuilder var typePicker: some View {
        if CreatePostViewModel.PostType.available(recipeFirst: FeatureFlags.shared.recipeFirst).count > 1 {
            SegmentedPills(
                options: [
                    .init(value: CreatePostViewModel.PostType.recipe, title: String(localized: "Recipe")),
                    .init(value: CreatePostViewModel.PostType.post, title: String(localized: "Post")),
                ],
                selection: $viewModel.postType
            )
        }
    }

    func handleTypeSwipe(_ value: DragGesture.Value) {
        // Recipe-first has one type, so the swipe toggle does nothing.
        guard !FeatureFlags.shared.recipeFirst else { return }
        // Only act on clearly horizontal swipes and only when the keyboard is down,
        // to avoid destroying in-progress text or fighting keyboard gestures.
        guard !keyboardVisible else { return }
        let dx = value.translation.width
        let dy = value.translation.height
        guard abs(dx) > 60, abs(dx) > abs(dy) * 1.5 else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.postType = dx < 0 ? .post : .recipe
        }
    }
}
