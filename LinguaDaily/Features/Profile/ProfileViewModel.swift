import Foundation
import Combine

struct ProfileScreenState: Hashable {
    var profile: UserProfile
    var progress: ProgressSnapshot
}

@MainActor
final class ProfileViewModel: ObservableObject {
    @Published var phase: AsyncPhase<ProfileScreenState> = .idle
    @Published var isEditingProfile = false
    @Published var isSavingProfile = false
    @Published var availableLanguages: [Language] = []
    @Published var editDisplayName = ""
    @Published var editSelectedLanguage: Language?
    @Published var editLearningGoal: LearningGoal = .travel
    @Published var editLevel: LearningLevel = .beginner
    @Published var editError: ViewError?

    private let progressService: ProgressServiceProtocol
    private let onboardingService: OnboardingServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState

    init(
        progressService: ProgressServiceProtocol,
        onboardingService: OnboardingServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        appState: AppState
    ) {
        self.progressService = progressService
        self.onboardingService = onboardingService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
    }

    func load() async {
        phase = .loading
        do {
            async let profileTask = progressService.fetchProfile()
            async let progressTask = progressService.fetchProgress()
            let state = ProfileScreenState(
                profile: try await profileTask,
                progress: try await progressTask
            )
            appState.appearancePreference = state.profile.appearancePreference
            phase = .success(state)
            analytics.track(.profileOpened, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "profile_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func beginEditingProfile() async {
        guard case let .success(state) = phase else {
            return
        }

        editDisplayName = state.profile.displayName
        editSelectedLanguage = state.profile.activeLanguage
        editLearningGoal = state.profile.learningGoal
        editLevel = state.profile.level
        editError = nil

        if availableLanguages.isEmpty {
            do {
                availableLanguages = try await onboardingService.fetchAvailableLanguages()
            } catch {
                crash.capture(error, context: ["feature": "profile_load_languages"])
                editError = (error as? AppError)?.viewError ?? .generic
            }
        }

        if editSelectedLanguage == nil {
            editSelectedLanguage = availableLanguages.first
        }

        isEditingProfile = true
    }

    func dismissProfileEditor() {
        isEditingProfile = false
        editError = nil
    }

    func saveProfile() async {
        guard case let .success(state) = phase else {
            return
        }

        isSavingProfile = true
        defer { isSavingProfile = false }

        do {
            let updatedProfile = try await progressService.updateProfile(
                UserProfileUpdateRequest(
                    displayName: editDisplayName,
                    activeLanguage: editSelectedLanguage ?? state.profile.activeLanguage,
                    learningGoal: editLearningGoal,
                    level: editLevel,
                    preferredAccent: state.profile.preferredAccent,
                    dailyLearningMode: state.profile.dailyLearningMode,
                    appearancePreference: state.profile.appearancePreference
                )
            )
            let refreshedProgress = (try? await progressService.fetchProgress()) ?? state.progress
            let refreshedState = ProfileScreenState(profile: updatedProfile, progress: refreshedProgress)
            phase = .success(refreshedState)
            appState.onboardingState = OnboardingState.completed(from: updatedProfile)
            appState.appearancePreference = updatedProfile.appearancePreference
            analytics.track(.profileUpdated, properties: [
                "language": updatedProfile.activeLanguage?.code ?? "none",
                "level": updatedProfile.level.rawValue
            ])
            isEditingProfile = false
            editError = nil
        } catch {
            crash.capture(error, context: ["feature": "profile_save"])
            editError = (error as? AppError)?.viewError ?? .generic
        }
    }

    func clearEditError() {
        editError = nil
    }
}
