import Foundation

struct NotificationPreference: Codable, Hashable {
    var isEnabled: Bool
    var reminderTime: Date
    var timezoneIdentifier: String
}
