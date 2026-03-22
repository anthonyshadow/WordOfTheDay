import Foundation
import Combine

@MainActor
final class SettingsViewModel: ObservableObject {
    @Published var phase: AsyncPhase<NotificationPreference> = .idle
    @Published var reminder = Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: Date()) ?? Date()
    @Published private(set) var sentryTestStatusMessage: String?

    private let notificationService: NotificationServiceProtocol
    private let authService: AuthServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState

    init(
        notificationService: NotificationServiceProtocol,
        authService: AuthServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        appState: AppState
    ) {
        self.notificationService = notificationService
        self.authService = authService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
    }

    func load() async {
        phase = .loading
        do {
            let preference = try await notificationService.loadPreference()
            reminder = preference.reminderTime
            phase = .success(preference)
            analytics.track(.settingsOpened, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "settings_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func toggleNotifications(_ enabled: Bool) async {
        guard case var .success(preference) = phase else {
            return
        }
        preference.isEnabled = enabled
        await savePreference(preference)
    }

    func updateReminder(_ date: Date) async {
        guard case var .success(preference) = phase else {
            return
        }
        preference.reminderTime = date
        analytics.track(.reminderTimeSet, properties: ["source": "settings"])
        await savePreference(preference)
    }

    func logOut() async {
        do {
            try await authService.signOut()
            analytics.reset()
            crash.setUser(nil)
            appState.session = nil
            appState.subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
            appState.resetNavigation()
        } catch {
            crash.capture(error, context: ["feature": "settings_logout"])
        }
    }

    func deleteAccount() async {
        // v1 stub: full backend delete-account workflow should remove auth user + profile + progress.
        do {
            try await authService.signOut()
            analytics.reset()
            crash.setUser(nil)
            appState.session = nil
            appState.subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
            appState.resetNavigation()
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

    private func savePreference(_ preference: NotificationPreference) async {
        do {
            try await notificationService.updatePreference(preference)
            if preference.isEnabled {
                try await notificationService.scheduleLocalReminder(preference: preference)
            }
            phase = .success(preference)
        } catch {
            crash.capture(error, context: ["feature": "settings_save_notification"])
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
