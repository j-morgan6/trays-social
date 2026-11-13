import Foundation

/// W258: where a collections load stands. `CollectionsViewModel.load()` only
/// logs a failure (D95), so without this the editor could not tell a failed
/// load from a user with no collections, and would show the picker card with
/// only New to someone whose collections simply did not arrive.
enum CollectionsLoadState: Equatable, Sendable {
    case idle
    case loading
    case loaded
    case failed
}

/// W258: one collection the new post will be added to after it is published.
/// The name travels with the id so the Posted screen and the failure toast can
/// say where it went without looking the collection up again.
struct CollectionAddTarget: Equatable, Sendable {
    let id: Int
    let name: String
}

/// W258: the Add to a collection (Optional) card in the recipe editor. Holds
/// only the selection, in tap order; the collections themselves stay on
/// `CollectionsViewModel`, so there is never a second copy to drift. Pure, so
/// every rule here is tested without a view or the network.
struct CollectionPickerState: Equatable {
    enum Visibility: Equatable {
        case hidden
        case shown
    }

    /// Selected collection ids in the order they were tapped.
    private(set) var selectedIDs: [Int] = []

    var hasSelection: Bool {
        !selectedIDs.isEmpty
    }

    func isSelected(_ id: Int) -> Bool {
        selectedIDs.contains(id)
    }

    /// A tap on a collection chip: selects it at the end, or deselects it.
    mutating func toggle(_ id: Int) {
        if let index = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: index)
        } else {
            selectedIDs.append(id)
        }
    }

    /// A collection created from the card's New button is selected straight
    /// away. Never toggles it off, so a repeat call is harmless.
    mutating func selectNew(_ id: Int) {
        guard !selectedIDs.contains(id) else { return }
        selectedIDs.append(id)
    }

    /// Brings the selection in line with the current collections. A pending
    /// (optimistic, negative) id whose create was confirmed follows its
    /// server id via `confirmed`; an id that is gone (deleted elsewhere, or a
    /// create that rolled back) drops out. Order is kept and never duplicated.
    mutating func sync(with collections: [RecipeCollection], confirmed: [Int: Int]) {
        let present = Set(collections.map(\.id))
        var kept: [Int] = []
        for id in selectedIDs {
            let resolved = present.contains(id) ? id : confirmed[id]
            guard let resolved, present.contains(resolved), !kept.contains(resolved) else { continue }
            kept.append(resolved)
        }
        selectedIDs = kept
    }

    /// The adds to run after publishing, in tap order. A selected id with no
    /// matching collection is skipped. A pending id stays in the plan so the
    /// runner can report it rather than silently dropping it.
    func followUpPlan(from collections: [RecipeCollection]) -> [CollectionAddTarget] {
        selectedIDs.compactMap { id in
            collections.first { $0.id == id }.map { CollectionAddTarget(id: $0.id, name: $0.name) }
        }
    }

    /// The card shows only to a Plus user whose collections loaded. Adding to
    /// a collection is a Plus-gated write, so a non-Plus user sees no card
    /// rather than a paywall in the middle of posting. A failed load hides it
    /// (logged, never toasted), and so does a load still running, so the card
    /// never flashes in and out. A loaded empty list still shows, with New.
    static func visibility(isPlus: Bool, loadState: CollectionsLoadState) -> Visibility {
        isPlus && loadState == .loaded ? .shown : .hidden
    }
}

/// W258: how the follow-up adds went, by collection name, in plan order.
struct CollectionAddResult: Equatable, Sendable {
    var added: [String] = []
    var failed: [String] = []

    static let none = CollectionAddResult()

    /// One write-path toast naming every collection the post did not reach,
    /// or nil when every add landed. The post itself is posted either way.
    var failureToastMessage: String? {
        guard !failed.isEmpty else { return nil }
        let names = failed.formatted(.list(type: .and))
        return String(localized: "Posted, but couldn't add it to \(names). Try again from My Tray.")
    }

    /// Adds the post to each target in turn. Every failure (a collection
    /// deleted elsewhere, a lapsed subscription, the network) is counted
    /// against that collection only and the rest still run. There is no
    /// paywall path: this runs behind the Posted screen. A pending target
    /// (negative id, create not yet confirmed) fails without a request,
    /// because the server would answer 404 for it.
    @MainActor
    static func run(
        _ plan: [CollectionAddTarget],
        postID: Int,
        add: @MainActor (_ collectionID: Int, _ postID: Int) async throws -> Void
    ) async -> CollectionAddResult {
        var result = CollectionAddResult()
        for target in plan {
            guard target.id > 0 else {
                result.failed.append(target.name)
                continue
            }
            do {
                try await add(target.id, postID)
                result.added.append(target.name)
            } catch {
                result.failed.append(target.name)
            }
        }
        return result
    }
}
