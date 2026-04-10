import SwiftUI
import Combine

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
            // Silently fail
        }

        isLoadingTrending = false
    }

    func search() {
        searchTask?.cancel()
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }

            isSearching = true

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
            } catch {
                // Silently fail
            }

            isSearching = false
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
        searchText = ""
        activeFilter = nil
        posts = []
        users = []
    }
}

struct SearchResults: Decodable, Sendable {
    let posts: [Post]
    let users: [User]
}
