import Foundation
import UIKit
import UserNotifications

final class StubNotificationService: NotificationServiceProtocol, PushRegistrationServiceProtocol {
    private var preference = NotificationPreference(
        isEnabled: false,
        reminderTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
        timezoneIdentifier: TimeZone.current.identifier
    )

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run { UIApplication.shared.registerForRemoteNotifications() }
            }
            return granted
        } catch {
            return false
        }
    }

    func loadPreference() async throws -> NotificationPreference {
        preference
    }

    func updatePreference(_ preference: NotificationPreference) async throws {
        self.preference = preference
    }

    func scheduleLocalReminder(preference: NotificationPreference) async throws {
        let content = UNMutableNotificationContent()
        content.title = "Your LinguaDaily word is ready"
        content.body = "Tap to hear pronunciation and examples."
        content.sound = .default
        content.userInfo = ["route": "today"]

        let hour = Calendar.current.component(.hour, from: preference.reminderTime)
        let minute = Calendar.current.component(.minute, from: preference.reminderTime)

        var date = DateComponents()
        date.hour = hour
        date.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)

        let request = UNNotificationRequest(identifier: "daily_word_reminder", content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func fetchPreviewNotification(language: Language?) async throws -> NotificationPreview {
        let languageName = language?.name ?? "French"
        let previewWord: String
        switch language?.code.lowercased() {
        case "it":
            previewWord = "Ciao"
        case "es":
            previewWord = "Hola"
        case "ja":
            previewWord = "こんにちは"
        case "ko":
            previewWord = "안녕하세요"
        case "zh":
            previewWord = "你好"
        case "de":
            previewWord = "Hallo"
        default:
            previewWord = "Bonjour"
        }

        return NotificationPreview(
            title: "Your \(languageName) word is ready: \(previewWord)",
            body: "Tap to hear pronunciation and examples."
        )
    }

    func registerDeviceToken(_ tokenData: Data) async throws {
        #if DEBUG
        print("[Push] token bytes=\(tokenData.count)")
        #endif
    }
}
