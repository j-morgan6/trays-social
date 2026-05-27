import Foundation

/// Lightweight bus that turns a thrown Swift `Error` into a user-friendly
/// banner. ViewModels and Views call `ErrorReporter.report(error)` from
/// inside a `catch` block; `AppState` listens on the
/// `.traysErrorOccurred` notification and surfaces the message through
/// `ErrorToast`.
///
/// Using NotificationCenter (rather than a singleton AppState) keeps
/// ViewModels free of any AppState dependency — they don't have to be
/// constructed with an environment reference.
enum ErrorReporter {
    /// Map a thrown error to a plain-language sentence and post it to
    /// the toast bus. Apple's `error.localizedDescription` is never
    /// shown verbatim; it leaks Cocoa-style copy that confuses users.
    static func report(_ error: Error, fallback: String = "Something went wrong. Please try again.") {
        report(message: userMessage(for: error, fallback: fallback))
    }

    /// Post a pre-built message directly. Use this when there's no
    /// throwable Error in hand (e.g., a non-throwing API returned a
    /// failure flag).
    static func report(message: String) {
        NotificationCenter.default.post(
            name: .traysErrorOccurred,
            object: nil,
            userInfo: ["message": message]
        )
    }

    /// Translate a thrown error into a plain-language sentence. Visible
    /// to tests + AppState so the same mapping powers both the toast
    /// surface and any per-flow inline error UI that wants to share
    /// copy.
    static func userMessage(for error: Error, fallback: String = "Something went wrong. Please try again.") -> String {
        if let api = error as? APIError {
            return api.errorDescription ?? fallback
        }

        let ns = error as NSError
        if ns.domain == NSURLErrorDomain {
            switch ns.code {
            case NSURLErrorNotConnectedToInternet,
                 NSURLErrorNetworkConnectionLost,
                 NSURLErrorTimedOut,
                 NSURLErrorDataNotAllowed:
                return "Couldn't load — check your connection."
            case NSURLErrorCannotFindHost,
                 NSURLErrorCannotConnectToHost,
                 NSURLErrorDNSLookupFailed:
                return "Couldn't reach the server. Please try again."
            case NSURLErrorCancelled:
                return fallback
            default:
                return "Network problem. Please try again."
            }
        }

        if ns.domain == NSCocoaErrorDomain, ns.code == 3840 {
            // JSON decode failure
            return "Unexpected response from the server."
        }

        return fallback
    }
}

extension Notification.Name {
    /// Posted by `ErrorReporter.report(...)`. `AppState` listens on
    /// this notification and forwards `userInfo["message"]` to its
    /// `showError(_:)` entry point so the toast surfaces.
    static let traysErrorOccurred = Notification.Name("traysErrorOccurred")
}
