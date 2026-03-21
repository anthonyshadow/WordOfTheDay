import Foundation
import UIKit
import UserNotifications

final class StubNotificationService: NotificationServiceProtocol {
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
}
