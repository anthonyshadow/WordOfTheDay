import Foundation

struct NotificationPreference: Codable, Hashable {
    var isEnabled: Bool
    var reminderTime: Date
    var timezoneIdentifier: String
}

struct NotificationPreview: Codable, Hashable {
    let title: String
    let body: String
}
