import Foundation

/// `GET /search?grouped=true`. `everyone` is FeedItem-shaped because
/// sponsored tiles can appear there; `tray` and `following` never carry ads.
struct GroupedSearchResults: Decodable, Sendable {
    let users: [User]
    let tray: [Post]
    let following: [Post]
    let everyone: [FeedItem]

    var isEmpty: Bool {
        users.isEmpty && tray.isEmpty && following.isEmpty && everyone.isEmpty
    }
}

/// `GET /search?group=...`, one paginated group.
struct SearchGroupPage: Decodable, Sendable {
    let posts: [FeedItem]
}

/// `GET /search/browse`.
struct BrowsePayload: Decodable, Sendable {
    let categories: [BrowseCategory]
    let mostSaved: [FeedItem]
}

struct BrowseCategory: Decodable, Identifiable, Sendable, Hashable {
    let key: String
    let label: String

    var id: String {
        key
    }

    /// Localized label for the keys this build knows; the server label for
    /// anything newer.
    var displayLabel: String {
        switch key {
        case "quick_dinners": String(localized: "Quick dinners")
        case "chicken": String(localized: "Chicken")
        case "pasta": String(localized: "Pasta")
        case "breakfast": String(localized: "Breakfast")
        case "baking": String(localized: "Baking")
        case "soups": String(localized: "Soups")
        default: label
        }
    }
}

enum SearchGroup: String, Hashable, Sendable {
    case tray
    case following
    case everyone

    var title: String {
        switch self {
        case .tray: String(localized: "In your tray")
        case .following: String(localized: "From people you follow")
        case .everyone: String(localized: "Everyone")
        }
    }
}

/// Pushed onto `AppState.navigationPath` by "See all" in grouped results.
/// Precedent: `CollectionRoute`.
struct SearchGroupRoute: Hashable, Sendable {
    let group: SearchGroup
    let query: String
    let categoryKey: String?
}

/// Query items for the search endpoints. Pure so it can be unit tested.
/// Query text travels only as `URLQueryItem` values, never spliced into a path.
enum SearchQuery {
    static func grouped(text: String, categoryKey: String?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "grouped", value: "true")]
        if !text.isEmpty {
            items.append(.init(name: "q", value: text))
        }
        if let categoryKey {
            items.append(.init(name: "category", value: categoryKey))
        }
        return items
    }

    /// Typing replaces a selected Browse category; whitespace alone does not.
    static func category(afterTyping text: String, selected: BrowseCategory?) -> BrowseCategory? {
        text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? selected : nil
    }

    static func groupPage(_ route: SearchGroupRoute, cursor: String?) -> [URLQueryItem] {
        var items = [URLQueryItem(name: "group", value: route.group.rawValue)]
        if !route.query.isEmpty {
            items.append(.init(name: "q", value: route.query))
        }
        if let key = route.categoryKey {
            items.append(.init(name: "category", value: key))
        }
        if let cursor {
            items.append(.init(name: "cursor", value: cursor))
        }
        return items
    }
}
