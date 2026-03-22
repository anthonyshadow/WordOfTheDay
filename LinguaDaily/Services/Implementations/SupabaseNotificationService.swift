import Foundation
import Supabase
import UIKit
import UserNotifications

final class SupabaseNotificationService: NotificationServiceProtocol, PushRegistrationServiceProtocol {
    private let client: SupabaseClient
    private let defaultPreference: NotificationPreference

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
        self.defaultPreference = NotificationPreference(
            isEnabled: false,
            reminderTime: SupabaseFieldParser.defaultReminderTime(),
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
        let userID = try await currentUserID()

        do {
            let rows: [SupabaseNotificationPreferenceRowDTO] = try await client
                .from("notification_preferences")
                .select("user_id,is_enabled,reminder_time,timezone,push_token")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value

            guard let row = rows.first else {
                return defaultPreference
            }

            return NotificationPreference(
                isEnabled: row.is_enabled,
                reminderTime: SupabaseFieldParser.reminderTime(from: row.reminder_time) ?? defaultPreference.reminderTime,
                timezoneIdentifier: row.timezone
            )
        } catch {
            throw normalize(error, fallback: "Could not load notification settings.")
        }
    }

    func updatePreference(_ preference: NotificationPreference) async throws {
        let userID = try await currentUserID()
        let existingRow = try await fetchPreferenceRow(userID: userID)

        guard let reminderTime = SupabaseFieldParser.sqlTimeString(from: preference.reminderTime) else {
            throw AppError.validation("Reminder time is invalid.")
        }

        do {
            try await client
                .from("notification_preferences")
                .upsert(
                    SupabaseNotificationPreferenceMutationDTO(
                        user_id: userID,
                        is_enabled: preference.isEnabled,
                        reminder_time: reminderTime,
                        timezone: preference.timezoneIdentifier,
                        push_token: existingRow?.push_token
                    ),
                    onConflict: "user_id",
                    returning: .minimal
                )
                .execute()
        } catch {
            throw normalize(error, fallback: "Could not update notification settings.")
        }
    }

    func scheduleLocalReminder(preference: NotificationPreference) async throws {
        let identifier = "daily_word_reminder"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

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
        let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
        try await UNUserNotificationCenter.current().add(request)
    }

    func fetchPreviewNotification(language: Language?) async throws -> NotificationPreview {
        guard let language else {
            return NotificationPreview(
                title: "Your daily word is ready",
                body: "Tap to hear pronunciation and examples."
            )
        }

        do {
            let words: [SupabasePreviewWordDTO] = try await client
                .from("words")
                .select("lemma")
                .eq("language_id", value: language.id)
                .order("frequency_rank", ascending: true)
                .limit(1)
                .execute()
                .value

            let previewWord = words.first?.lemma ?? language.nativeName
            return NotificationPreview(
                title: "Your \(language.name) word is ready: \(previewWord)",
                body: "Tap to hear pronunciation and examples."
            )
        } catch {
            throw normalize(error, fallback: "Could not load the notification preview.")
        }
    }

    func registerDeviceToken(_ tokenData: Data) async throws {
        let userID = try await currentUserID()
        let existingRow = try await fetchPreferenceRow(userID: userID)
        let preference = NotificationPreference(
            isEnabled: existingRow?.is_enabled ?? defaultPreference.isEnabled,
            reminderTime: SupabaseFieldParser.reminderTime(from: existingRow?.reminder_time) ?? defaultPreference.reminderTime,
            timezoneIdentifier: existingRow?.timezone ?? defaultPreference.timezoneIdentifier
        )

        guard let reminderTime = SupabaseFieldParser.sqlTimeString(from: preference.reminderTime) else {
            throw AppError.validation("Reminder time is invalid.")
        }

        do {
            try await client
                .from("notification_preferences")
                .upsert(
                    SupabaseNotificationPreferenceMutationDTO(
                        user_id: userID,
                        is_enabled: preference.isEnabled,
                        reminder_time: reminderTime,
                        timezone: preference.timezoneIdentifier,
                        push_token: Self.hexString(from: tokenData)
                    ),
                    onConflict: "user_id",
                    returning: .minimal
                )
                .execute()
        } catch {
            throw normalize(error, fallback: "Could not register this device for push notifications.")
        }
    }

    private func currentUserID() async throws -> UUID {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw normalize(error, fallback: "You need to sign in to manage notifications.")
        }
    }

    private func fetchPreferenceRow(userID: UUID) async throws -> SupabaseNotificationPreferenceRowDTO? {
        do {
            let rows: [SupabaseNotificationPreferenceRowDTO] = try await client
                .from("notification_preferences")
                .select("user_id,is_enabled,reminder_time,timezone,push_token")
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw normalize(error, fallback: "Could not load notification settings.")
        }
    }

    private func normalize(_ error: Error, fallback: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? fallback : message)
    }

    static func hexString(from tokenData: Data) -> String {
        tokenData.map { String(format: "%02x", $0) }.joined()
    }
}

private struct SupabaseNotificationPreferenceRowDTO: Decodable {
    let user_id: UUID
    let is_enabled: Bool
    let reminder_time: String
    let timezone: String
    let push_token: String?
}

private struct SupabaseNotificationPreferenceMutationDTO: Encodable {
    let user_id: UUID
    let is_enabled: Bool
    let reminder_time: String
    let timezone: String
    let push_token: String?
}

private struct SupabasePreviewWordDTO: Decodable {
    let lemma: String
}
