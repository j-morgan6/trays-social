import OSLog
import SwiftUI

/// What a failed collection *write* should do.
///
/// Extracted as a pure static for the same reason `PlusGateOutcome.decide` was
/// (W176): the project has no view-test or network-mock infrastructure, so a
/// decision left inline in a `catch` is asserted by nothing — and this one
/// decides whether a lapsed subscriber sees the paywall or a dead-end error
/// toast. The three 403/422 shapes the collections API can return look alike
/// from a distance; only the `subscription_required` code is a sales moment.
enum CollectionWriteOutcome: Equatable {
    case presentPaywall
    case toast

    static func decide(for error: Error) -> CollectionWriteOutcome {
        guard let api = error as? APIError, case .subscriptionRequired = api else {
            return .toast
        }
        return .presentPaywall
    }
}

/// Client-side name check. The server is still authoritative (422); this exists
/// so the three common rejections never cost a round trip or an optimistic row
/// that vanishes a second later.
enum CollectionNameValidation: Equatable {
    /// Associated value is the trimmed name.
    case valid(String)
    case empty
    /// Longer than 60 characters, matching `Collection.changeset`.
    case tooLong
    case duplicate

    var message: String? {
        switch self {
        case .valid: nil
        case .empty: String(localized: "Give your collection a name.")
        case .tooLong: String(localized: "Collection names can be up to 60 characters.")
        case .duplicate: String(localized: "You already have a collection with that name.")
        }
    }
}

/// Owns the collections shelf in My Tray: list, create, rename, delete, and
/// add-post. Read failures are silent (D95); write failures either toast or
/// present the paywall, never both.
///
/// Networking goes straight through `APIClient.shared`, matching every other
/// list-shaped ViewModel in the app — there is deliberately no service seam.
@MainActor
@Observable
final class CollectionsViewModel {
    var collections: [RecipeCollection] = []
    var isLoading = false
    /// Flipped by a server 403 `subscription_required` on a gated write, and
    /// directly by the context menu's free-user branch. `MyTrayView` binds it
    /// to `.plusPaywall`.
    var needsPaywall = false
    /// The recipe a locked user was trying to file when the paywall appeared.
    /// `PlusGate` re-runs its action on unlock so the user lands where they were
    /// headed; the manual locked branches have to carry their intent by hand or
    /// a fresh subscriber's very first action is silently dropped.
    private(set) var pendingAdd: Post?

    private var nextPendingID = -1
    private var pendingDeletes: [Int: (index: Int, collection: RecipeCollection)] = [:]
    private static let log = Logger(subsystem: "com.trays.social", category: "collections")
    private static let maxNameLength = 60

    var hasCollections: Bool {
        !collections.isEmpty
    }

    // MARK: - Read (D95: log only, never toast)

    func load() async {
        guard !isLoading else { return }
        isLoading = true
        do {
            let response: DataResponse<[RecipeCollection]> = try await APIClient.shared.get(
                path: "/collections"
            )
            collections = response.data
        } catch {
            Self.log.error("load failed: \(String(describing: error), privacy: .public)")
        }
        isLoading = false
    }

    func refresh() async {
        await load()
    }

    // MARK: - Create

    /// The optimistic half of a create, with no network. Split out so the state
    /// transition is testable on its own: driving `createCollection` from a test
    /// would spawn a real request whose failure toasts on a global bus shared
    /// with every other test in the process.
    ///
    /// Inserts at index 0 because the server sorts newest-first, so that is
    /// where the real row lands too.
    @discardableResult
    func beginCreate(name: String) -> (validation: CollectionNameValidation, pendingID: Int?) {
        let validation = Self.validate(name: name, existing: collections)
        guard case let .valid(trimmed) = validation else { return (validation, nil) }

        let pendingID = nextPendingID
        nextPendingID -= 1
        collections.insert(
            RecipeCollection(
                id: pendingID, name: trimmed, itemCount: 0,
                coverPhotoUrl: nil, insertedAt: Date()
            ),
            at: 0
        )
        return (validation, pendingID)
    }

    /// Returns the validation result so the form sheet can stay open on a bad
    /// name instead of dismissing into a row that vanishes.
    @discardableResult
    func createCollection(name: String) -> CollectionNameValidation {
        let (validation, pendingID) = beginCreate(name: name)
        guard let pendingID, case let .valid(trimmed) = validation else { return validation }

        Task { [weak self] in
            do {
                let response: DataResponse<RecipeCollection> = try await APIClient.shared.post(
                    path: "/collections", body: ["name": trimmed]
                )
                self?.confirmCreate(pendingID: pendingID, with: response.data)
            } catch {
                self?.rollbackCreate(pendingID: pendingID)
                self?.handleWriteFailure(error, operation: "create", toast: .collectionCreateFailed)
            }
        }
        return validation
    }

    /// Replaces the pending row **in place**. Never re-inserts at 0: a
    /// concurrent `load()` may have reordered or dropped it, and re-inserting
    /// would duplicate the row.
    func confirmCreate(pendingID: Int, with server: RecipeCollection) {
        guard let index = collections.firstIndex(where: { $0.id == pendingID }) else { return }
        collections[index] = server
        // A user who hit the paywall from "Add to collection", subscribed, and
        // was then walked through creating their first collection meant to file
        // that recipe. Finish the job.
        if let post = consumePendingAdd() {
            addPost(post, to: server.id)
        }
    }

    func rollbackCreate(pendingID: Int) {
        collections.removeAll { $0.id == pendingID }
    }

    // MARK: - Rename

    /// Optimistic half of a rename; returns the pre-rename value for rollback.
    @discardableResult
    func beginRename(
        id: Int,
        to newName: String
    ) -> (validation: CollectionNameValidation, original: RecipeCollection?) {
        let validation = Self.validate(name: newName, existing: collections, excludingID: id)
        guard case let .valid(trimmed) = validation,
              let index = collections.firstIndex(where: { $0.id == id })
        else {
            return (validation, nil)
        }
        let original = collections[index]
        collections[index] = original.renamed(to: trimmed)
        return (validation, original)
    }

    @discardableResult
    func renameCollection(id: Int, to newName: String) -> CollectionNameValidation {
        let (validation, original) = beginRename(id: id, to: newName)
        guard let original, case let .valid(trimmed) = validation else { return validation }

        Task { [weak self] in
            do {
                let response: DataResponse<RecipeCollection> = try await APIClient.shared.patch(
                    path: "/collections/\(id)", body: ["name": trimmed]
                )
                self?.confirmRename(id: id, with: response.data)
            } catch {
                self?.rollbackRename(id: id, to: original)
                self?.handleWriteFailure(error, operation: "rename", toast: .collectionRenameFailed)
            }
        }
        return validation
    }

    func confirmRename(id: Int, with server: RecipeCollection) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index] = server
    }

    func rollbackRename(id: Int, to original: RecipeCollection) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index] = original
    }

    // MARK: - Delete (never gated server-side — graceful re-lock)

    /// Optimistic half of a delete; `false` means there was nothing to remove.
    @discardableResult
    func beginDelete(id: Int) -> Bool {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return false }
        pendingDeletes[id] = (index: index, collection: collections[index])
        collections.remove(at: index)
        return true
    }

    func deleteCollection(id: Int) {
        guard beginDelete(id: id) else { return }

        Task { [weak self] in
            do {
                _ = try await APIClient.shared.delete(path: "/collections/\(id)")
                self?.confirmDelete(id: id)
            } catch {
                self?.rollbackDelete(id: id)
                self?.handleWriteFailure(error, operation: "delete", toast: .collectionDeleteFailed)
            }
        }
    }

    func confirmDelete(id: Int) {
        pendingDeletes.removeValue(forKey: id)
    }

    func rollbackDelete(id: Int) {
        guard let stashed = pendingDeletes.removeValue(forKey: id) else { return }
        collections.insert(stashed.collection, at: min(stashed.index, collections.count))
    }

    // MARK: - Add post

    /// Optimistic half of an add: bumps the count **and** takes the added
    /// post's photo as the cover, because that is what the server will compute.
    /// Returns the pre-add value; rolling the whole value back is what keeps
    /// the count and cover from ever disagreeing.
    @discardableResult
    func beginAdd(_ post: Post, to collectionID: Int) -> RecipeCollection? {
        guard let index = collections.firstIndex(where: { $0.id == collectionID }) else { return nil }
        let original = collections[index]
        collections[index] = original.addingItem(coverPhotoUrl: post.primaryPhotoURL)
        return original
    }

    func addPost(_ post: Post, to collectionID: Int) {
        guard let original = beginAdd(post, to: collectionID) else { return }

        Task { [weak self] in
            do {
                _ = try await APIClient.shared.post(path: "/collections/\(collectionID)/posts/\(post.id)")
            } catch {
                self?.rollbackAdd(id: collectionID, to: original)
                self?.handleWriteFailure(error, operation: "add", toast: .collectionAddFailed)
            }
        }
    }

    func rollbackAdd(id: Int, to original: RecipeCollection) {
        guard let index = collections.firstIndex(where: { $0.id == id }) else { return }
        collections[index] = original
    }

    // MARK: - Locked-intent replay

    /// A locked user tapped "Add to collection". Remember the recipe, then open
    /// the paywall.
    func requestAddWhileLocked(_ post: Post) {
        pendingAdd = post
        needsPaywall = true
    }

    /// Called after the paywall dismisses having actually unlocked.
    ///
    /// Returns whether the caller should open the create-collection form: a
    /// brand-new subscriber has no collections yet, so there is nothing to file
    /// into, and `confirmCreate` finishes the add once the collection exists.
    /// With exactly one collection the choice is unambiguous and we file it
    /// directly. With two or more it is not, so the intent is dropped and the
    /// user picks from the menu again.
    @discardableResult
    func replayPendingAdd() -> Bool {
        guard pendingAdd != nil else { return false }
        if collections.isEmpty {
            return true
        }
        guard let post = consumePendingAdd() else { return false }
        if collections.count == 1, let only = collections.first {
            addPost(post, to: only.id)
        }
        return false
    }

    /// Takes the remembered recipe, if any, and clears it. Split from the
    /// callers so the hand-off is assertable without issuing a request.
    func consumePendingAdd() -> Post? {
        defer { pendingAdd = nil }
        return pendingAdd
    }

    /// The user backed out — dismissed the paywall without subscribing, or
    /// cancelled the create form. The intent must die with the interaction that
    /// created it: `MyTrayView`'s state lives as long as the session, so a
    /// surviving intent would be consumed by the next unrelated `confirmCreate`
    /// and silently file a recipe nobody asked for.
    func cancelPendingAdd() {
        pendingAdd = nil
    }

    // MARK: - Cross-screen sync

    /// `CollectionDetailView` removed an item. My Tray never unmounts (the tab
    /// shell keeps it alive), so `.task` will not re-fire on the way back —
    /// this notification is what keeps the shelf's count honest.
    func applyItemRemoved(collectionId: Int) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[index] = collections[index].removingItem()
    }

    /// The detail screen's remove failed and was rolled back.
    func applyItemRestored(collectionId: Int) {
        guard let index = collections.firstIndex(where: { $0.id == collectionId }) else { return }
        collections[index] = collections[index].withItemCount(collections[index].itemCount + 1)
    }

    // MARK: - Failure funnel

    /// Single funnel for every write. Guarantees the 403-is-a-paywall rule
    /// holds everywhere, and that a paywall never *also* fires a toast.
    ///
    /// Returns the branch it took. The `switch` already makes the two mutually
    /// exclusive, but returning it is what lets a test assert *which* one ran
    /// without watching a global notification bus — that bus is shared with
    /// every other in-flight mutation in the process, so "no toast was posted"
    /// is not a claim a test can make about one call.
    @discardableResult
    func handleWriteFailure(_ error: Error, operation: String, toast: Toast) -> CollectionWriteOutcome {
        Self.log.error(
            "\(operation, privacy: .public) failed: \(String(describing: error), privacy: .public)"
        )
        let outcome = CollectionWriteOutcome.decide(for: error)
        switch outcome {
        case .presentPaywall: needsPaywall = true
        case .toast: toast.show()
        }
        return outcome
    }

    // MARK: - Validation

    static func validate(
        name: String,
        existing: [RecipeCollection],
        excludingID: Int? = nil
    ) -> CollectionNameValidation {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return .empty }
        guard trimmed.count <= maxNameLength else { return .tooLong }
        // Stricter than the server's case-sensitive index on purpose: two
        // collections differing only in case are indistinguishable on a shelf.
        let clash = existing.contains {
            $0.id != excludingID && $0.name.caseInsensitiveCompare(trimmed) == .orderedSame
        }
        return clash ? .duplicate : .valid(trimmed)
    }
}

extension Notification.Name {
    /// Posted by `CollectionDetailViewModel` after an optimistic remove.
    /// Mirrors the existing `.postDeleted` / `.postDeleteFailed` pair.
    static let collectionItemRemoved = Notification.Name("trays.collectionItemRemoved")
    static let collectionItemRestored = Notification.Name("trays.collectionItemRestored")
}
