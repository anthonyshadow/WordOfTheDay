import Foundation

protocol NotificationServiceProtocol {
    func requestAuthorization() async -> Bool
    func loadPreference() async throws -> NotificationPreference
    func updatePreference(_ preference: NotificationPreference) async throws
    func scheduleLocalReminder(preference: NotificationPreference) async throws
}
