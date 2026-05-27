import Combine
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
    var activeFilter: String?

    private var searchTask: Task<Void, Never>?

    var showSearchResults: Bool {
        !searchText.isEmpty || activeFilter != nil
    }

    func loadTrending() async {
        isLoadingTrending = true

        do {
            let response: DataResponse<[Post]> = try await APIClient.shared.get(path: "/posts/trending")
            trendingPosts = response.data
        } catch {
            ErrorReporter.report(error, fallback: "Couldn't load trending recipes.")
        }

        isLoadingTrending = false
    }

    func search() {
        searchTask?.cancel()

        // Nothing to search — clear results and bail
        guard !searchText.isEmpty || activeFilter != nil else {
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
                var queryItems: [URLQueryItem] = []
                if !searchText.isEmpty {
                    queryItems.append(.init(name: "q", value: searchText))
                }
                if let filter = activeFilter {
                    switch filter {
                    case "Under 30 min":
                        queryItems.append(.init(name: "max_cooking_time", value: "30"))
                    default:
                        queryItems.append(.init(name: "tag", value: filter.lowercased()))
                    }
                }

                let response: DataResponse<SearchResults> = try await APIClient.shared.get(
                    path: "/search",
                    queryItems: queryItems
                )
                if !Task.isCancelled {
                    posts = response.data.posts
                    users = response.data.users
                }
            } catch is CancellationError {
                // ok: cancelled — the next search debounce will take over
                // and submitting a toast would race the new query.
            } catch {
                // API error — clear stale results
                if !Task.isCancelled {
                    posts = []
                    users = []
                    ErrorReporter.report(error, fallback: "Search failed. Please try again.")
                }
            }
        }
    }

    func toggleFilter(_ filter: String) {
        if activeFilter == filter {
            activeFilter = nil
        } else {
            activeFilter = filter
        }
        search()
    }

    func clearSearch() {
        searchTask?.cancel()
        searchTask = nil
        searchText = ""
        activeFilter = nil
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
