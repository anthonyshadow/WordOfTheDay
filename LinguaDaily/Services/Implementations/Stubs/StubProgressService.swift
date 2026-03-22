import Foundation

final class StubProgressService: ProgressServiceProtocol {
    func fetchProgress() async throws -> ProgressSnapshot {
        SampleData.progress
    }

    func fetchProfile() async throws -> UserProfile {
        SampleData.profile
    }

    func updateProfile(_ request: UserProfileUpdateRequest) async throws -> UserProfile {
        UserProfile(
            id: SampleData.profile.id,
            email: SampleData.profile.email,
            displayName: request.displayName,
            activeLanguage: request.activeLanguage,
            learningGoal: request.learningGoal,
            level: request.level,
            preferredAccent: request.preferredAccent,
            dailyLearningMode: request.dailyLearningMode,
            appearancePreference: request.appearancePreference,
            reminderTime: SampleData.profile.reminderTime,
            timezoneIdentifier: SampleData.profile.timezoneIdentifier,
            currentStreakDays: SampleData.profile.currentStreakDays,
            bestStreakDays: SampleData.profile.bestStreakDays,
            joinedAt: SampleData.profile.joinedAt
        )
    }

    func fetchAvailableAccents(languageID: UUID?) async throws -> [String] {
        ["parisian", "standard"]
    }
}
