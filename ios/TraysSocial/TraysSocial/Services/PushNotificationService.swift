import Foundation
import UserNotifications
import UIKit

enum PushNotificationService {
    static func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
        }
    }

    static func registerDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        _ = try? await APIClient.shared.post(path: "/devices", body: ["token": token, "platform": "ios"])
    }

    static func unregisterDeviceToken(_ tokenData: Data) async {
        let token = tokenData.map { String(format: "%02.2hhx", $0) }.joined()
        _ = try? await APIClient.shared.delete(path: "/devices/\(token)") as EmptyResponse
    }
}
