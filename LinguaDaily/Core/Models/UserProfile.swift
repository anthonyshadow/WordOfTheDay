import Foundation

enum LearningGoal: String, Codable, CaseIterable, Hashable {
    case travel
    case work
    case school
    case culture
    case family

    var title: String {
        switch self {
        case .travel: return "Travel"
        case .work: return "Work / career"
        case .school: return "School"
        case .culture: return "Culture / personal interest"
        case .family: return "Family / relationships"
        }
    }
}

enum LearningLevel: String, Codable, CaseIterable, Hashable {
    case beginner
    case intermediate
    case advanced

    var title: String {
        rawValue.capitalized
    }
}

struct UserProfile: Identifiable, Codable, Hashable {
    let id: UUID
    let email: String
    var displayName: String
    var activeLanguage: Language?
    var learningGoal: LearningGoal
    var level: LearningLevel
    var reminderTime: Date
    var timezoneIdentifier: String
    var joinedAt: Date
}

struct OnboardingState: Codable, Hashable {
    var goal: LearningGoal?
    var language: Language?
    var level: LearningLevel?
    var reminderTime: Date?
    var hasSeenNotificationEducation: Bool
    var hasRequestedNotificationPermission: Bool
    var isCompleted: Bool

    static let empty = OnboardingState(
        goal: nil,
        language: nil,
        level: nil,
        reminderTime: nil,
        hasSeenNotificationEducation: false,
        hasRequestedNotificationPermission: false,
        isCompleted: false
    )
}
