import OSLog
import PhotosUI
import SwiftUI

@MainActor
@Observable
final class CreatePostViewModel {
    private static let log = Logger(subsystem: "com.trays.social", category: "create-post")

    var postType: PostType = .recipe
    var caption = ""
    var cookingTimeMinutes = ""
    var servings = ""
    var ingredients: [IngredientEntry] = []
    var steps: [StepEntry] = []
    var tools: [String] = []
    var tags = ""
    var selectedPhoto: PhotosPickerItem?
    var photoData: Data?
    var photoImage: Image?
    var isUploading = false
    var isPublishing = false
    var errorMessage: String?
    /// W257: true once the server accepted the last publish (200 or 201),
    /// even when its body did not decode and `publish()` returned nil. The
    /// post exists then, so the view still treats it as posted.
    private(set) var didPublish = false

    /// W258: the user's collections, for the Add to a collection card. Loads
    /// only when the card can show (Plus); nothing is fetched at init.
    let collections = CollectionsViewModel()
    /// W258: which collections the new post goes into after it is published.
    var collectionPicker = CollectionPickerState()
    /// W258: true while the post is being added to the selected collections,
    /// between a successful create and the Posted screen.
    private(set) var isFilingIntoCollections = false

    /// Publishing, or filing the new post into collections: Post stays busy
    /// and the sheet stays put until both are done.
    var isBusy: Bool {
        isPublishing || isFilingIntoCollections
    }

    /// W257: swipe-down is refused while a publish is in flight, so the sheet
    /// never closes on a half-finished post; before and after, it closes.
    /// W258: the collection adds that follow a publish count as in flight.
    var allowsInteractiveDismiss: Bool {
        !isBusy
    }

    // Ingredient/step entry
    var newIngredientName = ""
    var newIngredientQuantity = ""
    var newIngredientUnit = ""
    var newStepText = ""
    var newToolName = ""

    enum PostType: String, CaseIterable {
        case recipe, post

        /// Recipe-first (W196) offers only recipes; the server rule is authoritative.
        static func available(recipeFirst: Bool) -> [PostType] {
            recipeFirst ? [.recipe] : [.recipe, .post]
        }
    }

    struct IngredientEntry: Identifiable {
        let id = UUID()
        let name: String
        let quantity: String
        let unit: String
    }

    struct StepEntry: Identifiable {
        let id = UUID()
        let description: String
    }

    func loadPhoto() async {
        guard let item = selectedPhoto else { return }
        if let data = try? await item.loadTransferable(type: Data.self) {
            photoData = data
            if let uiImage = UIImage(data: data) {
                photoImage = Image(uiImage: uiImage)
            }
        }
    }

    func addIngredient() {
        guard !newIngredientName.isEmpty else { return }
        ingredients.append(IngredientEntry(name: newIngredientName, quantity: newIngredientQuantity, unit: newIngredientUnit))
        newIngredientName = ""
        newIngredientQuantity = ""
        newIngredientUnit = ""
    }

    func addStep() {
        guard !newStepText.isEmpty else { return }
        steps.append(StepEntry(description: newStepText))
        newStepText = ""
    }

    func addTool() {
        guard !newToolName.isEmpty else { return }
        tools.append(newToolName)
        newToolName = ""
    }

    func removeIngredient(at index: Int) {
        ingredients.remove(at: index)
    }

    func removeStep(at index: Int) {
        steps.remove(at: index)
    }

    func removeTool(at index: Int) {
        tools.remove(at: index)
    }

    /// W257: returns the new post decoded from the create response, or nil.
    /// Nil with `didPublish` true means the server accepted the post but its
    /// body did not decode; nil with `didPublish` false is a failure, and
    /// `errorMessage` says what to do in user copy.
    func publish() async -> Post? {
        // Auto-add any pending input before publishing
        if !newIngredientName.isEmpty {
            addIngredient()
        }
        if !newStepText.isEmpty {
            addStep()
        }
        if !newToolName.isEmpty {
            addTool()
        }

        guard let photoData else {
            errorMessage = "Please select a photo"
            return nil
        }

        isPublishing = true
        errorMessage = nil
        didPublish = false

        do {
            // Upload photo first
            let photoURL = try await APIClient.shared.upload(
                path: "/uploads",
                imageData: photoData,
                filename: "photo.jpg"
            )

            // Build post params
            var params: [String: Any] = [
                "type": postType.rawValue,
                "caption": caption,
                "photo_url": photoURL,
                "post_photos": [["url": photoURL, "position": 0]],
            ]

            if postType == .recipe {
                if let time = Int(cookingTimeMinutes) {
                    params["cooking_time_minutes"] = time
                }
                if let srv = Int(servings) {
                    params["servings"] = srv
                }
                params["ingredients"] = ingredients.enumerated().map { i, ing -> [String: Any] in
                    ["name": ing.name, "quantity": ing.quantity, "unit": ing.unit, "order": i]
                }
                params["cooking_steps"] = steps.enumerated().map { i, step -> [String: Any] in
                    ["description": step.description, "order": i]
                }
                params["tools"] = tools.enumerated().map { i, tool -> [String: Any] in
                    ["name": tool, "order": i]
                }
            }

            let tagList = tags.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }
            if !tagList.isEmpty {
                params["post_tags"] = tagList.map { ["tag": $0] }
            }

            // Create post — use raw JSON since mixed types
            let jsonData = try JSONSerialization.data(withJSONObject: params)
            var request = URLRequest(url: URL(string: Configuration.apiBaseURL + "/api/v1/posts")!)
            request.httpMethod = "POST"
            request.httpBody = jsonData
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            if let token = KeychainService.getToken() {
                request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            }

            let (data, response) = try await URLSession.shared.data(for: request)
            return handleCreateResponse(data: data, status: (response as? HTTPURLResponse)?.statusCode ?? 0)
        } catch {
            Self.log.error("Publish failed before the server answered")
            errorMessage = Self.failureMessage(for: error)
            isPublishing = false
            return nil
        }
    }
}

// MARK: - Collection follow-up adds (W258)

extension CreatePostViewModel {
    /// One add of the new post to a collection. The real one is
    /// `addToCollection(collectionID:postID:)`; tests pass a recording closure.
    typealias CollectionAdd = @MainActor (_ collectionID: Int, _ postID: Int) async throws -> Void

    /// How long filing waits for a collection made with New to confirm.
    static let pendingCreateWait: Duration = .seconds(5)

    /// The adds a publish should run: none unless the card was showing when
    /// Post was tapped (`enabled`) and this is a recipe. Re-syncs first, so a
    /// collection deleted or a create confirmed since the last tap is right.
    func collectionFollowUpPlan(enabled: Bool) -> [CollectionAddTarget] {
        guard enabled, postType == .recipe else { return [] }
        collectionPicker.sync(with: collections.collections, confirmed: collections.confirmedIDs)
        return collectionPicker.followUpPlan(from: collections.collections)
    }

    /// After a publish returns: file into the selected collections, then post
    /// `.postCreated` (W170: Home, Feed and My Tray refresh on it), so My Tray
    /// reloads with the new counts. Announced once whenever the post exists,
    /// never for a failure. Returns what the Posted screen and toast report.
    func settlePublish(
        _ outcome: PublishOutcome,
        filesIntoCollections enabled: Bool,
        center: NotificationCenter = .default,
        add: CollectionAdd = CreatePostViewModel.addToCollection(collectionID:postID:)
    ) async -> CollectionAddResult {
        let filed: CollectionAddResult = switch outcome {
        case .failed:
            .none
        case .closed:
            unfiledResult(enabled: enabled)
        case let .posted(post):
            await fileIntoSelectedCollections(post: post, enabled: enabled, add: add)
        }
        outcome.announce(on: center)
        return filed
    }

    /// Adds the new post to each selected collection in turn; a failed add
    /// never unposts it. A collection made with New just before Post may be
    /// pending: wait up to `pendingWait` for it to confirm, not report it.
    func fileIntoSelectedCollections(
        post: Post,
        enabled: Bool,
        pendingWait: Duration = CreatePostViewModel.pendingCreateWait,
        add: CollectionAdd = CreatePostViewModel.addToCollection(collectionID:postID:)
    ) async -> CollectionAddResult {
        guard !collectionFollowUpPlan(enabled: enabled).isEmpty else { return .none }
        isFilingIntoCollections = true
        defer { isFilingIntoCollections = false }
        let plan = await planAfterPendingCreates(enabled: enabled, wait: pendingWait)
        return await CollectionAddResult.run(plan, postID: post.id, add: add)
    }

    /// The plan once nothing selected is pending, or `wait` runs out. A create
    /// that rolls back drops out on the re-sync (its own failure toasted).
    private func planAfterPendingCreates(enabled: Bool, wait: Duration) async -> [CollectionAddTarget] {
        let clock = ContinuousClock()
        let deadline = clock.now.advanced(by: wait)
        var plan = collectionFollowUpPlan(enabled: enabled)
        while plan.contains(where: { $0.id < 0 }), clock.now < deadline {
            try? await Task.sleep(for: .milliseconds(100))
            plan = collectionFollowUpPlan(enabled: enabled)
        }
        return plan
    }

    /// The server took the post but its body did not decode, so there is no
    /// post id to file: every selected collection is reported as not reached.
    func unfiledResult(enabled: Bool) -> CollectionAddResult {
        CollectionAddResult(failed: collectionFollowUpPlan(enabled: enabled).map(\.name))
    }

    /// POST /collections/:id/posts/:post_id. Logs carry the collection id and
    /// the error only, never a name or a body.
    static func addToCollection(collectionID: Int, postID: Int) async throws {
        do {
            _ = try await APIClient.shared.post(path: "/collections/\(collectionID)/posts/\(postID)")
        } catch {
            let reason = String(describing: error)
            log.error("Collection add failed: \(collectionID, privacy: .public), \(reason, privacy: .public)")
            throw error
        }
    }
}

// MARK: - Create response (W257)

extension CreatePostViewModel {
    /// What the editor does once a publish returns.
    enum PublishOutcome: Equatable {
        /// The server refused it or never answered; the editor stays, with copy.
        case failed
        /// The server took it (200 or 201) but its body did not decode: the
        /// post exists, so close as before rather than show an error.
        case closed
        /// The server took it and returned it: show the Posted screen.
        case posted(Post)

        init(didPublish: Bool, post: Post?) {
            switch (didPublish, post) {
            case (false, _): self = .failed
            case (true, nil): self = .closed
            case let (true, post?): self = .posted(post)
            }
        }

        /// W170: Home, Feed and My Tray refresh on `.postCreated`. Posted once
        /// for every outcome where the post exists, never for a failure.
        func announce(on center: NotificationCenter = .default) {
            guard self != .failed else { return }
            center.post(name: .postCreated, object: nil)
        }
    }

    /// 200 or 201 means the post exists; anything else sets user copy. Logs
    /// carry the status and byte count only, never the body or the bearer.
    /// Internal so tests can drive it with a status and a body.
    func handleCreateResponse(data: Data, status: Int) -> Post? {
        isPublishing = false
        let bytes = data.count
        guard (200 ... 201).contains(status) else {
            Self.log.error("Create post failed: status \(status, privacy: .public), \(bytes, privacy: .public) bytes")
            errorMessage = Self.failureMessage(status: status, data: data)
            return nil
        }

        didPublish = true
        do {
            return try Self.createdPost(from: data)
        } catch {
            Self.log.error("Create body did not decode: \(status, privacy: .public), \(bytes, privacy: .public) bytes")
            return nil
        }
    }

    private nonisolated static var genericFailure: String {
        String(localized: "Couldn't post your recipe. Please try again.")
    }

    /// The new post from the create response, `{"data": Post}` as rendered by
    /// PostController.create/2, decoded with APIClient's settings (snake case
    /// keys, ISO 8601 dates). Throws when the body has no `data` rather than
    /// producing a stand-in post.
    nonisolated static func createdPost(from data: Data) throws -> Post {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(DataResponse<Post>.self, from: data).data
    }

    /// User copy for a failed create. Fixed sentences per status only: `data`
    /// is the raw response body and is never echoed, not even 422 field
    /// messages, because it can name server internals.
    nonisolated static func failureMessage(status: Int, data _: Data) -> String {
        switch status {
        case 401:
            APIError.unauthorized.errorDescription ?? genericFailure
        case 403:
            APIError.forbidden.errorDescription ?? genericFailure
        case 413:
            String(localized: "That photo is too large. Try a smaller one.")
        case 422:
            String(localized: "Some details couldn't be saved. Check the recipe and try again.")
        case 429:
            APIError.rateLimited.errorDescription ?? genericFailure
        default:
            genericFailure
        }
    }

    /// User copy for an error thrown before the create answered (the photo
    /// upload, or the network). APIError's own descriptions are not used:
    /// several echo server-supplied strings (validation field messages,
    /// conflict and suspension text), so each maps to the same fixed copy as
    /// `failureMessage(status:data:)`. Network errors use ErrorReporter's
    /// fixed sentences.
    nonisolated static func failureMessage(for error: Error) -> String {
        guard let api = error as? APIError else {
            return ErrorReporter.userMessage(for: error, fallback: genericFailure)
        }
        let status = switch api {
        case .unauthorized: 401
        case .forbidden, .suspended, .subscriptionRequired, .paidTierDisabled: 403
        case .validationError, .unprocessableEntity: 422
        case .rateLimited: 429
        case let .serverError(code): code
        case .invalidURL, .invalidResponse, .notFound, .conflict: 0
        }
        return failureMessage(status: status, data: Data())
    }
}
