import Foundation
import os
import UIKit
import UserNotifications

private let pushLog = Logger(subsystem: "com.trays.social", category: "push")

/// W169: APNs registration pipeline. Until this task the three functions
/// here had zero call sites and no AppDelegate existed to receive the token
/// callback — no device had ever uploaded a token, so every backend push
/// went nowhere.
enum PushNotificationService {
    /// APNs device tokens are rotating device identifiers, not credentials —
    /// UserDefaults is the appropriate store. Remembered so logout can
    /// unregister and a failed upload can be retried on the next sync.
    private static let tokenDefaultsKey = "apnsDeviceToken"

    static var storedToken: String? {
        UserDefaults.standard.string(forKey: tokenDefaultsKey)
    }

    /// Called from AppShellView's .task — i.e. contextually after login,
    /// never at cold pre-auth launch. First run prompts; later runs
    /// re-register silently (APNs tokens rotate, and a login by a different
    /// account must rebind the token server-side).
    static func syncRegistration() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            switch settings.authorizationStatus {
            case .notDetermined:
                requestPermission()
            case .authorized, .provisional, .ephemeral:
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            case .denied:
                break
            @unknown default:
                break
            }
        }
    }

    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            if let error {
                pushLog.error("push permission request failed: \(String(describing: error), privacy: .public)")
            }
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    /// AppDelegate hands the raw token here. Stored, then uploaded with
    /// retry — a single network blip on first launch must not mean
    /// "never registered until reinstall".
    static func handleDeviceToken(_ tokenData: Data) {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        UserDefaults.standard.set(token, forKey: tokenDefaultsKey)

        Task {
            await upload(token: token)
        }
    }

    static func upload(token: String, attempts: Int = 3) async {
        for attempt in 1 ... attempts {
            do {
                _ = try await APIClient.shared.post(path: "/devices", body: ["token": token, "platform": "ios"])
                pushLog.info("device token registered (attempt \(attempt))")
                return
            } catch {
                pushLog.error("device token upload failed (attempt \(attempt)): \(String(describing: error), privacy: .public)")

                // Terminal rejections won't succeed on retry — stop; the next
                // shell mount re-registers anyway. Transport errors, rate
                // limits, and 5xx are worth the backoff.
                if case let apiError as APIError = error {
                    switch apiError {
                    case .unauthorized, .forbidden, .notFound, .unprocessableEntity, .validationError:
                        return
                    default:
                        break
                    }
                }

                if attempt < attempts {
                    try? await Task.sleep(for: .seconds(Double(attempt) * 2))
                }
            }
        }
    }
}
