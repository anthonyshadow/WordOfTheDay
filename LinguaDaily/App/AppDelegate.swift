import Foundation
import UIKit
import UserNotifications

final class LinguaDailyAppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    static var onDeepLinkTarget: ((DeepLinkTarget) -> Void)?
    static var onPushOpened: ((String) -> Void)?
    static var onPushTokenReceived: ((Data) -> Void)?

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        Self.onPushTokenReceived?(deviceToken)
        #if DEBUG
        print("[APNs] token bytes=\(deviceToken.count)")
        #endif
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        if let route = response.notification.request.content.userInfo["route"] as? String {
            Self.onPushOpened?(route)
            switch route {
            case "today":
                Self.onDeepLinkTarget?(.today)
            case "review":
                Self.onDeepLinkTarget?(.review)
            default:
                break
            }
        }
        completionHandler()
    }
}
