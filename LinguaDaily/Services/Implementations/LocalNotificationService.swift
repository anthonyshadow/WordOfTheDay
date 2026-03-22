import Foundation
import UIKit
import UserNotifications

final class LocalNotificationService: NotificationServiceProtocol {
    private enum StorageKey {
        static let preference = "notification_preference"
        static let reminderIdentifier = "daily_word_reminder"
    }

    private let store: LocalKeyValueStore
    private let defaultPreference: NotificationPreference

    init(store: LocalKeyValueStore) {
        self.store = store
        self.defaultPreference = NotificationPreference(
            isEnabled: false,
            reminderTime: Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date(),
            timezoneIdentifier: TimeZone.current.identifier
        )
    }

    func requestAuthorization() async -> Bool {
        do {
            let granted = try await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            if granted {
                await MainActor.run {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            }
            return granted
        } catch {
            return false
        }
    }

    func loadPreference() async throws -> NotificationPreference {
        try store.get(NotificationPreference.self, for: StorageKey.preference) ?? defaultPreference
    }

    func updatePreference(_ preference: NotificationPreference) async throws {
        try store.set(preference, for: StorageKey.preference)

        if !preference.isEnabled {
            UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [StorageKey.reminderIdentifier])
        }
    }

    func scheduleLocalReminder(preference: NotificationPreference) async throws {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [StorageKey.reminderIdentifier])

        guard preference.isEnabled else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Your LinguaDaily word is ready"
        content.body = "Tap to hear pronunciation and examples."
        content.sound = .default
        content.userInfo = ["route": "today"]

        let calendar = Calendar.current
        let reminderTimezone = TimeZone(identifier: preference.timezoneIdentifier) ?? .current
        let hour = calendar.component(.hour, from: preference.reminderTime)
        let minute = calendar.component(.minute, from: preference.reminderTime)

        var date = DateComponents()
        date.timeZone = reminderTimezone
        date.hour = hour
        date.minute = minute

        let trigger = UNCalendarNotificationTrigger(dateMatching: date, repeats: true)
        let request = UNNotificationRequest(
            identifier: StorageKey.reminderIdentifier,
            content: content,
            trigger: trigger
        )
        try await UNUserNotificationCenter.current().add(request)
    }

    func fetchPreviewNotification(language: Language?) async throws -> NotificationPreview {
        let languageName = language?.name ?? "Language"
        let previewWord = language?.nativeName ?? "Word"
        return NotificationPreview(
            title: "Your \(languageName) word is ready: \(previewWord)",
            body: "Tap to hear pronunciation and examples."
        )
    }
}
