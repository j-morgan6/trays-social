import Foundation
import OSLog

/// W263: what a feedback submission is about. The server accepts exactly
/// these two values and defaults to `feedback` when a build sends neither.
enum FeedbackKind: String, CaseIterable, Hashable, Encodable, Sendable {
    case bug
    case feedback
}

/// W263: where the feedback sheet was opened from. The raw value is what the
/// server stores as `screen`, so the admin view can tell a report from the
/// verify-email gate apart from one sent from Settings.
enum FeedbackEntryPoint: String, Sendable {
    case settings
    case verifyEmail = "verify_email"

    var screen: String {
        rawValue
    }

    /// Someone stuck on the verify-email gate is most likely reporting a
    /// problem, so that entry point opens on Bug; Settings keeps Feedback.
    var defaultKind: FeedbackKind {
        self == .verifyEmail ? .bug : .feedback
    }
}

/// The device facts sent with every submission: app version, build, OS and
/// model, as the privacy policy's in-app feedback line describes (with the
/// screen the report came from). Nothing else about the device.
struct FeedbackDeviceInfo: Equatable, Sendable {
    let appVersion: String?
    let appBuild: String?
    let osVersion: String
    let deviceModel: String

    static let current = FeedbackDeviceInfo(
        appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
        appBuild: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String,
        osVersion: currentOSVersion,
        deviceModel: currentDeviceModel
    )

    private static var currentOSVersion: String {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }

    private static var currentDeviceModel: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }
}

/// The POST /api/v1/feedback body. `JSONEncoder.apiEncoder` writes the keys
/// in snake_case: kind, subject, body, app_version, app_build, os_version,
/// device_model, screen. The W125 keys keep their names so the server reads
/// old and new builds alike; `platform` is never sent (the server sets it).
/// A nil subject is left out of the JSON, as before.
struct FeedbackRequest: Encodable, Equatable, Sendable {
    let kind: FeedbackKind
    let subject: String?
    let body: String
    let appVersion: String?
    let appBuild: String?
    let osVersion: String
    let deviceModel: String
    let screen: String
}

/// W263: the feedback sheet's state, pulled out of `FeedbackView` so the
/// validation, limits, request and failure handling can be unit tested.
///
/// Submitting is a write, so a failure shows an inline message and keeps
/// the kind, subject and body exactly as typed for a retry. The send is
/// injected so tests can drive failures and an in-flight send without the
/// network. The typed text is never logged.
@MainActor
@Observable
final class FeedbackForm {
    typealias Send = @MainActor (FeedbackRequest) async throws -> Void

    enum State: Equatable {
        case editing
        case sending
        case sent
        case failed(message: String)
    }

    /// The server's limits, counted the way the server counts them: the
    /// body is 1 to 5,000 grapheme clusters after trimming (a text column),
    /// the subject at most 200 Unicode code points (a varchar column).
    static let bodyLimit = 5000
    static let subjectLimit = 200

    var kind: FeedbackKind
    var subject = ""
    var body = ""
    private(set) var state: State = .editing

    let entryPoint: FeedbackEntryPoint
    @ObservationIgnored private let device: FeedbackDeviceInfo
    @ObservationIgnored private let send: Send

    private static let log = Logger(subsystem: "com.trays.social", category: "feedback")

    init(
        entryPoint: FeedbackEntryPoint,
        kind: FeedbackKind? = nil,
        device: FeedbackDeviceInfo = .current,
        send: @escaping Send = FeedbackForm.liveSend
    ) {
        self.entryPoint = entryPoint
        self.kind = kind ?? entryPoint.defaultKind
        self.device = device
        self.send = send
    }

    static func liveSend(_ request: FeedbackRequest) async throws {
        try await APIClient.shared.submitFeedback(request)
    }

    // MARK: - Derived state

    var trimmedBody: String {
        body.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedSubject: String {
        subject.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// What the counter under the body shows: the trimmed length, which is
    /// what the server checks against the limit.
    var bodyCount: Int {
        trimmedBody.count
    }

    var bodyIsOverLimit: Bool {
        bodyCount > Self.bodyLimit
    }

    /// Code points, not characters: a subject of 200 accented letters built
    /// from combining marks is 400 code points and the server refuses it.
    var subjectIsOverLimit: Bool {
        trimmedSubject.unicodeScalars.count > Self.subjectLimit
    }

    var isSending: Bool {
        state == .sending
    }

    var isSent: Bool {
        state == .sent
    }

    var errorMessage: String? {
        if case let .failed(message) = state {
            return message
        }
        return nil
    }

    /// A non-blank body, and both fields within their limits.
    var isValid: Bool {
        !trimmedBody.isEmpty && !bodyIsOverLimit && !subjectIsOverLimit
    }

    var canSubmit: Bool {
        isValid && !isSending && !isSent
    }

    // MARK: - Actions

    /// The request a submit would send, or nil when the form is not valid.
    func makeRequest() -> FeedbackRequest? {
        guard isValid else { return nil }
        let subject = trimmedSubject
        return FeedbackRequest(
            kind: kind,
            subject: subject.isEmpty ? nil : subject,
            body: trimmedBody,
            appVersion: device.appVersion,
            appBuild: device.appBuild,
            osVersion: device.osVersion,
            deviceModel: device.deviceModel,
            screen: entryPoint.screen
        )
    }

    /// Send the report. Ignored while a send is in flight, after a send
    /// succeeded, and when the form is not valid.
    func submit() async {
        guard canSubmit, let request = makeRequest() else { return }
        state = .sending
        do {
            try await send(request)
            state = .sent
            let kind = request.kind.rawValue
            let screen = request.screen
            Self.log.info("feedback sent kind=\(kind, privacy: .public) screen=\(screen, privacy: .public)")
        } catch {
            // Kind, subject and body stay exactly as typed for the retry.
            state = .failed(message: Self.message(for: error))
            Self.log.error("feedback send failed: \(Self.logCategory(error), privacy: .public)")
        }
    }

    /// Editing after a failure clears the message.
    func clearError() {
        guard case .failed = state else { return }
        state = .editing
    }

    /// The inline message for a failed send. The only server-supplied text
    /// it can show is a suspension notice, through the existing
    /// `APIError.suspended` copy; validation and other error bodies are
    /// never echoed.
    static func message(for error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited:
                return String(localized: "Too many reports in the last hour. Try again later.")
            case .unauthorized, .suspended:
                // The existing session-expired and suspension copy.
                return ErrorReporter.userMessage(for: error, fallback: genericFailure)
            default:
                return genericFailure
            }
        }
        if (error as NSError).domain == NSURLErrorDomain {
            return String(localized: "Couldn't send your feedback. Check your connection and try again.")
        }
        return genericFailure
    }

    private static var genericFailure: String {
        String(localized: "Couldn't send your feedback. Please try again.")
    }

    /// A category for the log line. Never the subject, body or server text.
    private static func logCategory(_ error: Error) -> String {
        if let apiError = error as? APIError {
            switch apiError {
            case .rateLimited: return "rateLimited"
            case .unauthorized: return "unauthorized"
            case .validationError, .unprocessableEntity: return "validation"
            case let .serverError(code): return "server(\(code))"
            default: return "api"
            }
        }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain {
            return "network(\(nsError.code))"
        }
        return "other"
    }
}
