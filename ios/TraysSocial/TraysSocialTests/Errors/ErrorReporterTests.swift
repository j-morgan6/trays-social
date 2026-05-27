@testable import TraysSocial
import XCTest

@MainActor
final class ErrorReporterTests: XCTestCase {
    // MARK: - Mapping

    func test_userMessage_apiErrorUnauthorized_isFriendly() {
        let message = ErrorReporter.userMessage(for: APIError.unauthorized)
        XCTAssertEqual(message, "Session expired. Please log in again.")
    }

    func test_userMessage_notConnectedToInternet_isFriendly() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorNotConnectedToInternet)
        let message = ErrorReporter.userMessage(for: error)
        XCTAssertEqual(message, "Couldn't load — check your connection.")
    }

    func test_userMessage_cannotFindHost_isFriendly() {
        let error = NSError(domain: NSURLErrorDomain, code: NSURLErrorCannotFindHost)
        let message = ErrorReporter.userMessage(for: error)
        XCTAssertEqual(message, "Couldn't reach the server. Please try again.")
    }

    func test_userMessage_unknownError_returnsFallback() {
        struct Bogus: Error {}
        let message = ErrorReporter.userMessage(for: Bogus(), fallback: "custom fallback")
        XCTAssertEqual(message, "custom fallback")
    }

    // MARK: - AppState + NotificationCenter wiring

    func test_appState_showError_setsCurrentError() {
        let app = AppState()
        app.showError("first")
        XCTAssertEqual(app.currentError, "first")
    }

    func test_appState_showError_coalesces_latestMessageWins() {
        let app = AppState()
        app.showError("first")
        app.showError("second")
        XCTAssertEqual(app.currentError, "second")
    }

    func test_appState_dismissCurrentError_clearsImmediately() {
        let app = AppState()
        app.showError("oops")
        app.dismissCurrentError()
        XCTAssertNil(app.currentError)
    }

    func test_errorReporter_report_postsViaNotification_andAppStateConsumes() async {
        let app = AppState()
        let exp = expectation(description: "currentError populated via NotificationCenter")

        Task { @MainActor in
            ErrorReporter.report(message: "from-reporter")

            // Allow the run loop to deliver the notification + main-actor hop.
            for _ in 0 ..< 20 {
                if app.currentError == "from-reporter" {
                    exp.fulfill()
                    return
                }
                try? await Task.sleep(for: .milliseconds(20))
            }
        }

        await fulfillment(of: [exp], timeout: 1.0)
    }
}
