import Combine
import OSLog
import SwiftUI

@MainActor
@Observable
final class FindViewModel {
    var searchText = ""
    var posts: [Post] = []
    var users: [User] = []
    var trendingPosts: [Post] = []
    var popularTags: [String] = []
    var isSearching = false
    var isLoadingTrending = false

    private var searchTask: Task<Void, Never>?
    private static let log = Logger(subsystem: "com.trays.social", category: "find")

    var showSearchResults: Bool {
        !searchText.isEmpty
    }

    func loadTrending() async {
        isLoadingTrending = true

        do {
            let response: DataResponse<[Post]> = try await APIClient.shared.get(path: "/posts/trending")
            trendingPosts = response.data
        } catch {
            // D95: read-path failures stay silent — log only.
            Self.log.error("loadTrending failed: \(String(describing: error), privacy: .public)")
        }

        isLoadingTrending = false
    }

    func search() {
        searchTask?.cancel()

        // Nothing to search — clear results and bail
        guard !searchText.isEmpty else {
            posts = []
            users = []
            isSearching = false
            return
        }

        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true
            defer { isSearching = false }

            do {
                let response: DataResponse<SearchResults> = try await APIClient.shared.get(
                    path: "/search",
                    queryItems: [.init(name: "q", value: searchText)]
                )
                if !Task.isCancelled {
                    posts = response.data.posts
                    users = response.data.users
                }
            } catch is CancellationError {
                // ok: cancelled — the next search debounce will take over
                // and submitting a toast would race the new query.
            } catch {
                // D95: read-path failure — clear stale results and log;
                // the empty results UI is the user-visible affordance.
                if !Task.isCancelled {
                    posts = []
                    users = []
                    Self.log.error("search failed: \(String(describing: error), privacy: .public)")
                }
            }
        }
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        posts = []
        users = []
        isSearching = false
    }

    func cancelInFlight() {
        searchTask?.cancel()
        searchTask = nil
    }
}

struct SearchResults: Decodable, Sendable {
    let posts: [Post]
    let users: [User]
}
