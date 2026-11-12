import Foundation

/// W245: what a loaded screen shows (My Tray, a collection, a profile). Pure,
/// like `HomeScreenState`, so the rule is tested without a view.
///
/// Content always wins. Without content, a load that has not finished yet, or
/// a retry in flight, shows the skeleton; a finished load that failed shows
/// the error block; a finished load that succeeded with nothing is empty.
enum ContentLoadState: Equatable {
    case loading
    case error
    case empty
    case content

    static func decide(hasContent: Bool, hasLoaded: Bool, isLoading: Bool, loadFailed: Bool) -> ContentLoadState {
        if hasContent {
            return .content
        }
        if isLoading || !hasLoaded {
            return .loading
        }
        return loadFailed ? .error : .empty
    }
}

/// W245: what a failed collection load says. A 404 means the collection is
/// gone (deleted, or not the viewer's), so it says so and offers no retry;
/// anything else is treated as a connection problem.
struct CollectionLoadErrorCopy: Equatable {
    let title: String
    let subtitle: String
    let allowsRetry: Bool

    static func decide(notFound: Bool) -> CollectionLoadErrorCopy {
        if notFound {
            return CollectionLoadErrorCopy(
                title: String(localized: "This collection is gone."),
                subtitle: String(localized: "It may have been deleted."),
                allowsRetry: false
            )
        }
        return CollectionLoadErrorCopy(
            title: String(localized: "Couldn't load this collection"),
            subtitle: String(localized: "Check your connection and try again."),
            allowsRetry: true
        )
    }
}
