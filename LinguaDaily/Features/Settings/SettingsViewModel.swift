import Foundation
import Combine

struct SettingsScreenState: Hashable {
    var notificationPreference: NotificationPreference
    var profile: UserProfile
    var availableAccents: [String]
}

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var phase: AsyncPhase<SettingsScreenState> = .idle
    @Published var reminder = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published private(set) var sentryTestStatusMessage: String?

    private let notificationService: NotificationServiceProtocol
    private let progressService: ProgressServiceProtocol
    private let authService: AuthServiceProtocol
    private let onboardingService: OnboardingServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState

    init(
        notificationService: NotificationServiceProtocol,
        progressService: ProgressServiceProtocol,
        authService: AuthServiceProtocol,
        onboardingService: OnboardingServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        appState: AppState
    ) {
        self.notificationService = notificationService
        self.progressService = progressService
        self.authService = authService
        self.onboardingService = onboardingService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
    }

    func load() async {
        phase = .loading
        do {
            async let preferenceTask = notificationService.loadPreference()
            async let profileTask = progressService.fetchProfile()
            let profile = try await profileTask
            let availableAccents = try await progressService.fetchAvailableAccents(languageID: profile.activeLanguage?.id)
            let preference = try await preferenceTask

            let state = SettingsScreenState(
                notificationPreference: preference,
                profile: profile,
                availableAccents: availableAccents
            )
            reminder = preference.reminderTime
            appState.appearancePreference = profile.appearancePreference
            phase = .success(state)
            analytics.track(.settingsOpened, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "settings_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func toggleNotifications(_ enabled: Bool) async {
        guard case var .success(state) = phase else {
            return
        }
        state.notificationPreference.isEnabled = enabled
        await savePreference(state.notificationPreference, currentState: state)
    }

    func updateReminder(_ date: Date) async {
        guard case var .success(state) = phase else {
            return
        }
        state.notificationPreference.reminderTime = date
        analytics.track(.reminderTimeSet, properties: ["source": "settings"])
        await savePreference(state.notificationPreference, currentState: state)
    }

    func updatePreferredAccent(_ accent: String?) async {
        await updateProfile(field: "preferred_accent") { profile in
            profile.preferredAccent = accent
        }
    }

    func updateDailyLearningMode(_ mode: DailyLearningMode) async {
        await updateProfile(field: "daily_learning_mode") { profile in
            profile.dailyLearningMode = mode
        }
    }

    func updateAppearance(_ appearance: AppearancePreference) async {
        await updateProfile(field: "appearance") { profile in
            profile.appearancePreference = appearance
        }
    }

    func logOut() async {
        do {
            try await authService.signOut()
            try? onboardingService.saveOnboardingState(.empty)
            analytics.reset()
            crash.setUser(nil)
            appState.resetForSignedOutUser()
        } catch {
            crash.capture(error, context: ["feature": "settings_logout"])
        }
    }

    func deleteAccount() async {
        do {
            analytics.track(.accountDeleted, properties: [:])
            try await authService.deleteAccount()
            try? onboardingService.saveOnboardingState(.empty)
            analytics.reset()
            crash.setUser(nil)
            appState.resetForSignedOutUser()
        } catch {
            crash.capture(error, context: ["feature": "settings_delete_account"])
        }
    }

    func sendSentryTestEvent() {
        crash.capture(
            SettingsDebugSentryTestError(),
            context: [
                "feature": "settings_debug_sentry",
                "trigger": "manual",
                "screen": "settings",
                "authenticated": appState.session == nil ? "false" : "true"
            ]
        )
        sentryTestStatusMessage = "Sent a handled Sentry test event. Check Sentry in a moment."
    }

    private func savePreference(_ preference: NotificationPreference, currentState: SettingsScreenState) async {
        do {
            try await notificationService.updatePreference(preference)
            if preference.isEnabled {
                try await notificationService.scheduleLocalReminder(preference: preference)
            }

            var nextState = currentState
            nextState.notificationPreference = preference
            phase = .success(nextState)
        } catch {
            crash.capture(error, context: ["feature": "settings_save_notification"])
        }
    }

    private func updateProfile(
        field: String,
        mutate: (inout UserProfile) -> Void
    ) async {
        guard case let .success(state) = phase else {
            return
        }

        var profile = state.profile
        mutate(&profile)

        do {
            let updatedProfile = try await progressService.updateProfile(
                UserProfileUpdateRequest(
                    displayName: profile.displayName,
                    activeLanguage: profile.activeLanguage,
                    learningGoal: profile.learningGoal,
                    level: profile.level,
                    preferredAccent: profile.preferredAccent,
                    dailyLearningMode: profile.dailyLearningMode,
                    appearancePreference: profile.appearancePreference
                )
            )

            let refreshedAccents = try await progressService.fetchAvailableAccents(languageID: updatedProfile.activeLanguage?.id)
            let updatedState = SettingsScreenState(
                notificationPreference: state.notificationPreference,
                profile: updatedProfile,
                availableAccents: refreshedAccents
            )
            appState.appearancePreference = updatedProfile.appearancePreference
            phase = .success(updatedState)
            analytics.track(.settingsUpdated, properties: ["field": field])
        } catch {
            crash.capture(error, context: ["feature": "settings_update_profile"])
        }
    }
}

private struct SettingsDebugSentryTestError: LocalizedError, CustomNSError {
    static var errorDomain: String {
        "com.linguadaily.debug.sentry"
    }

    var errorCode: Int {
        1001
    }

    var errorUserInfo: [String : Any] {
        [NSLocalizedDescriptionKey: errorDescription ?? "Manual Sentry test event from Settings"]
    }

    var errorDescription: String? {
        "Manual Sentry test event from Settings"
    }
}
