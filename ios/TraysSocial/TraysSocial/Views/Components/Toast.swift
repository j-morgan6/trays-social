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
    case actionFailed
    case custom(String)

    var message: String {
        switch self {
        case .likeFailed: "Couldn't like. Try again."
        case .saveFailed: "Couldn't save. Try again."
        case .unsaveFailed: "Couldn't remove from tray. Try again."
        case .followFailed: "Couldn't follow. Try again."
        case .unfollowFailed: "Couldn't unfollow. Try again."
        case .commentFailed: "Couldn't post your comment. Try again."
        case .actionFailed: "Couldn't complete that. Try again."
        case let .custom(text): text
        }
    }

    /// Fire-and-forget. Surfaces the toast immediately via the W113
    /// `ErrorReporter` bus.
    func show() {
        ErrorReporter.report(message: message)
    }
}
