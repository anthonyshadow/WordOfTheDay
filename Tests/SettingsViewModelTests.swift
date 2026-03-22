import XCTest
@testable import LinguaDaily

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadSuccessUpdatesReminderAndPhase() async {
        let notificationService = TestNotificationService()
        let expectedPreference = NotificationPreference(
            isEnabled: true,
            reminderTime: Date(timeIntervalSince1970: 1_700_010_000),
            timezoneIdentifier: "America/Toronto"
        )
        notificationService.preference = expectedPreference
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(notificationService: notificationService, analytics: analytics)

        await viewModel.load()

        XCTAssertEqual(viewModel.reminder, expectedPreference.reminderTime)
        guard case let .success(preference) = viewModel.phase else {
            return XCTFail("Expected success phase")
        }
        XCTAssertEqual(preference, expectedPreference)
        XCTAssertEqual(analytics.events.map(\.event), [.settingsOpened])
    }

    func testUpdateReminderPersistsAndSchedulesWhenEnabled() async {
        let notificationService = TestNotificationService()
        notificationService.preference = NotificationPreference(
            isEnabled: true,
            reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "UTC"
        )
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(notificationService: notificationService, analytics: analytics)
        await viewModel.load()
        let newReminder = Date(timeIntervalSince1970: 1_700_020_000)

        await viewModel.updateReminder(newReminder)

        XCTAssertEqual(notificationService.updatedPreferences.last?.reminderTime, newReminder)
        XCTAssertEqual(notificationService.scheduledPreferences.last?.reminderTime, newReminder)
        XCTAssertEqual(analytics.events.map(\.event), [.settingsOpened, .reminderTimeSet])
    }

    func testLogOutClearsSessionAndNavigation() async {
        let auth = TestAuthService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        appState.session = TestData.session()
        appState.subscriptionState = SubscriptionState(tier: .premium, isTrial: false, expiresAt: nil)
        appState.path = [.settings, .paywall]
        let viewModel = makeViewModel(auth: auth, analytics: analytics, crash: crash, appState: appState)

        await viewModel.logOut()

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertEqual(analytics.resetCallCount, 1)
        XCTAssertEqual(crash.userSessions, [nil])
        XCTAssertNil(appState.session)
        XCTAssertEqual(appState.subscriptionState.tier, .free)
        XCTAssertTrue(appState.path.isEmpty)
    }

    func testSendSentryTestEventCapturesHandledErrorAndSetsStatus() {
        let crash = TestCrashReportingService()
        let appState = AppState()
        appState.session = TestData.session()
        let viewModel = makeViewModel(crash: crash, appState: appState)

        viewModel.sendSentryTestEvent()

        XCTAssertEqual(crash.capturedErrors.count, 1)
        XCTAssertEqual(
            crash.contexts,
            [[
                "feature": "settings_debug_sentry",
                "trigger": "manual",
                "screen": "settings",
                "authenticated": "true"
            ]]
        )
        XCTAssertEqual(
            viewModel.sentryTestStatusMessage,
            "Sent a handled Sentry test event. Check Sentry in a moment."
        )
    }

    private func makeViewModel(
        notificationService: TestNotificationService = TestNotificationService(),
        auth: TestAuthService = TestAuthService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> SettingsViewModel {
        SettingsViewModel(
            notificationService: notificationService,
            authService: auth,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState()
        )
    }
}
