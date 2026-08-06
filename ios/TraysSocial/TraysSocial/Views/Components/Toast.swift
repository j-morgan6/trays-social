import Foundation

/// Locked rollback copy from the design spec, surfaced through the
/// existing `ErrorToast` overlay (mounted at the app root in W113).
///
/// W133 AC requires a typed `Toast` component that owns the strings
/// users see when an optimistic UI update fails. Centralizing the
/// copy here keeps every revert path consistent and refactor-safe
/// — change a sentence once, and every callsite picks it up.
///
/// Internally each case delegates to `ErrorReporter.report(message:)`
/// so the existing NotificationCenter → AppState → ErrorToast
/// pipeline does the actual presentation. No new view layer.
enum Toast {
    case likeFailed
    case saveFailed
    case unsaveFailed
    case followFailed
    case unfollowFailed
    case commentFailed
    case deleteFailed
    case editFailed
    case actionFailed
    // W177 collections. Distinct cases rather than five `.custom` callsites,
    // so the rollback copy stays owned here like every other mutation's.
    case collectionCreateFailed
    case collectionRenameFailed
    case collectionDeleteFailed
    case collectionAddFailed
    case collectionRemoveFailed
    case custom(String)

    var message: String {
        switch self {
        case .likeFailed: String(localized: "Couldn't like. Try again.")
        case .saveFailed: String(localized: "Couldn't save. Try again.")
        case .unsaveFailed: String(localized: "Couldn't remove from tray. Try again.")
        case .followFailed: String(localized: "Couldn't follow. Try again.")
        case .unfollowFailed: String(localized: "Couldn't unfollow. Try again.")
        case .commentFailed: String(localized: "Couldn't post your comment. Try again.")
        case .deleteFailed: String(localized: "Couldn't delete. Try again.")
        case .editFailed: String(localized: "Couldn't save changes. Try again.")
        case .actionFailed: String(localized: "Couldn't complete that. Try again.")
        case .collectionCreateFailed: String(localized: "Couldn't create that collection. Try again.")
        case .collectionRenameFailed: String(localized: "Couldn't rename that collection. Try again.")
        case .collectionDeleteFailed: String(localized: "Couldn't delete that collection. Try again.")
        case .collectionAddFailed: String(localized: "Couldn't add to that collection. Try again.")
        case .collectionRemoveFailed: String(localized: "Couldn't remove from that collection. Try again.")
        case let .custom(text): text
        }
    }

    /// Fire-and-forget. Surfaces the toast immediately via the W113
    /// `ErrorReporter` bus.
    func show() {
        ErrorReporter.report(message: message)
    }
}
