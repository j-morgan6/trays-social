import Foundation
import MetricKit
import os

/// MetricKit subscriber that forwards every `MXMetricPayload` and
/// `MXDiagnosticPayload` Apple delivers to the backend's
/// `/api/v1/ios_diagnostics` endpoint.
///
/// Apple's delivery cadence:
///   * `MXMetricPayload` — once per day per device, on launch after a
///     24-hour window closes.
///   * `MXDiagnosticPayload` — on next launch after the relevant crash,
///     hang, or CPU/disk exception occurred. Apple deduplicates retries
///     server-side; we do not.
///
/// Registration must happen exactly once. `TraysSocialApp.init` calls
/// `MetricKitReporter.shared.register()` so the subscriber stays
/// attached for the app's lifetime.
///
/// MetricKit only fires on physical devices — simulator builds will
/// load and register the subscriber, but Apple will never call back.
/// Real-device verification is the only way to confirm end-to-end
/// delivery (see W119 verification_steps).
@available(iOS 14.0, *)
final class MetricKitReporter: NSObject, @unchecked Sendable {
    static let shared = MetricKitReporter()

    private let log = Logger(subsystem: "com.trays.social", category: "metrickit")
    private let queue = DispatchQueue(label: "com.trays.social.metrickit", qos: .utility)
    private var registered = false

    override private init() {
        super.init()
    }

    /// Attach to `MXMetricManager.shared`. Safe to call multiple times —
    /// subsequent calls no-op so a misplaced `.onAppear` doesn't double-
    /// register and double-post every payload.
    func register() {
        guard !registered else { return }
        registered = true
        MXMetricManager.shared.add(self)
        log.info("MetricKit subscriber registered")
    }

    // MARK: - Posting

    /// Builds the request body and dispatches to APIClient. Failures are
    /// swallowed by design — Apple redelivers payloads across launches,
    /// and surfacing a toast for silent telemetry would be noisy. We do
    /// log at debug level for forensic detail.
    private func post(payloadType: String, payloadJSON: Data) {
        guard let payloadObject = try? JSONSerialization.jsonObject(with: payloadJSON) else {
            log.error("MetricKit: payload JSON not parsable; dropping")
            return
        }

        var envelope: [String: Any] = [
            "payload_type": payloadType,
            "payload": payloadObject,
        ]
        if let appVersion = Self.appVersion {
            envelope["app_version"] = appVersion
        }
        envelope["os_version"] = Self.osVersion
        envelope["device_model"] = Self.deviceModel

        guard let body = try? JSONSerialization.data(withJSONObject: envelope) else {
            log.error("MetricKit: envelope serialization failed; dropping")
            return
        }

        Task.detached(priority: .utility) { [log] in
            do {
                _ = try await APIClient.shared.postRaw(path: "/ios_diagnostics", jsonData: body)
                log.debug("MetricKit \(payloadType, privacy: .public) payload posted")
            } catch {
                // Silent on the wire: Apple redelivers, and we never want
                // a toast for background telemetry. Debug-level log keeps
                // the failure inspectable via Console.app.
                log.debug("MetricKit \(payloadType, privacy: .public) post failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    // MARK: - Device metadata

    private static let appVersion: String? = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String

    /// Use ProcessInfo (nonisolated) rather than UIDevice.current
    /// (MainActor-bound under Swift 6) so the static initializer
    /// doesn't have to hop to the main actor at first access.
    private static let osVersion: String = {
        let v = ProcessInfo.processInfo.operatingSystemVersion
        return "\(v.majorVersion).\(v.minorVersion).\(v.patchVersion)"
    }()

    private static let deviceModel: String = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let mirror = Mirror(reflecting: systemInfo.machine)
        let identifier = mirror.children.reduce("") { partial, element in
            guard let value = element.value as? Int8, value != 0 else { return partial }
            return partial + String(UnicodeScalar(UInt8(value)))
        }
        return identifier.isEmpty ? "unknown" : identifier
    }()
}

// MARK: - MXMetricManagerSubscriber

@available(iOS 14.0, *)
extension MetricKitReporter: MXMetricManagerSubscriber {
    func didReceive(_ payloads: [MXMetricPayload]) {
        // MX*Payload isn't Sendable in Swift 6 strict mode, so serialize
        // each payload to Data on the MetricKit callback thread before
        // hopping to the background queue. Data IS Sendable, so the
        // closure capture below is clean.
        let serialized: [Data] = payloads.map { $0.jsonRepresentation() }
        queue.async { [weak self] in
            guard let self else { return }
            for data in serialized {
                post(payloadType: "metric", payloadJSON: data)
            }
        }
    }

    func didReceive(_ payloads: [MXDiagnosticPayload]) {
        // Same Sendable-bridge trick as the metric path above —
        // jsonRepresentation() returns Sendable Data.
        let serialized: [Data] = payloads.map { $0.jsonRepresentation() }
        queue.async { [weak self] in
            guard let self else { return }
            for data in serialized {
                post(payloadType: "diagnostic", payloadJSON: data)
            }
        }
    }
}
