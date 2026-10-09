import SwiftUI

/// Which top-pill tab set the shell shows. Pure, like `PlannerEntryMode`.
enum ShellLayout: Equatable, Sendable {
    case classic
    case recipeFirst

    static func decide(recipeFirst: Bool) -> ShellLayout {
        recipeFirst ? .recipeFirst : .classic
    }

    var tabs: [AppState.TrayTab] {
        switch self {
        case .classic: [.feed, .myTray, .find]
        case .recipeFirst: [.home, .myTray, .search]
        }
    }

    var initialTab: AppState.TrayTab {
        switch self {
        case .classic: .myTray
        case .recipeFirst: .home
        }
    }

    /// Maps a selected tab onto this layout when the flag flips mid-session.
    func normalize(_ tab: AppState.TrayTab) -> AppState.TrayTab {
        if tabs.contains(tab) {
            return tab
        }
        switch tab {
        case .feed: return .home
        case .find: return .search
        case .home: return .feed
        case .search: return .find
        case .myTray: return .myTray
        }
    }

    /// The tab to show once the launch fetch has resolved this layout from
    /// the cached `old` one. A user still on the old layout's opening tab
    /// (or its normalized twin, if the flag's `onChange` already ran) moves
    /// to this layout's opening tab, so the first launch after the flag
    /// turns on lands on Home. Any other tab is mapped like a mid-session flip.
    func tabAfterLaunchFetch(from old: ShellLayout, current: AppState.TrayTab) -> AppState.TrayTab {
        guard old != self else { return current }
        let untouched = current == old.initialTab || current == normalize(old.initialTab)
        return untouched ? initialTab : normalize(current)
    }
}

extension AppState.TrayTab {
    var label: LocalizedStringKey {
        switch self {
        case .feed: "Feed"
        case .myTray: "My Tray"
        case .find: "Find"
        case .home: "Home"
        case .search: "Search"
        }
    }
}
