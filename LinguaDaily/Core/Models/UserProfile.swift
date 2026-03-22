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

enum DailyLearningMode: String, Codable, CaseIterable, Hashable {
    case balanced
    case reviewFocus = "review_focus"
    case dailyWordOnly = "daily_word_only"

    var title: String {
        switch self {
        case .balanced:
            return "1 new word + review"
        case .reviewFocus:
            return "Review first"
        case .dailyWordOnly:
            return "Daily word only"
        }
    }
}

enum AppearancePreference: String, Codable, CaseIterable, Hashable {
    case system
    case light
    case dark

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
    var preferredAccent: String?
    var dailyLearningMode: DailyLearningMode
    var appearancePreference: AppearancePreference
    var reminderTime: Date
    var timezoneIdentifier: String
    var currentStreakDays: Int
    var bestStreakDays: Int
    var joinedAt: Date
}

struct UserProfileUpdateRequest: Codable, Hashable {
    var displayName: String
    var activeLanguage: Language?
    var learningGoal: LearningGoal
    var level: LearningLevel
    var preferredAccent: String?
    var dailyLearningMode: DailyLearningMode
    var appearancePreference: AppearancePreference
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

extension OnboardingState {
    static func completed(from profile: UserProfile) -> OnboardingState {
        OnboardingState(
            goal: profile.learningGoal,
            language: profile.activeLanguage,
            level: profile.level,
            reminderTime: profile.reminderTime,
            hasSeenNotificationEducation: true,
            hasRequestedNotificationPermission: false,
            isCompleted: true
        )
    }
}
