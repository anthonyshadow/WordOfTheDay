import XCTest
@testable import LinguaDaily

@MainActor
final class SettingsViewModelTests: XCTestCase {
    func testLoadSuccessUpdatesReminderAndPhase() async {
        let notificationService = TestNotificationService()
        let progressService = TestProgressService()
        let expectedPreference = NotificationPreference(
            isEnabled: true,
            reminderTime: Date(timeIntervalSince1970: 1_700_010_000),
            timezoneIdentifier: "America/Toronto"
        )
        notificationService.preference = expectedPreference
        progressService.profileResult = .success(
            makeProfile(
                preferredAccent: "parisian",
                dailyLearningMode: .balanced,
                appearancePreference: .dark
            )
        )
        progressService.availableAccentsResult = .success(["parisian", "quebecois"])
        let analytics = TestAnalyticsService()
        let appState = AppState()
        let viewModel = makeViewModel(
            notificationService: notificationService,
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.reminder, expectedPreference.reminderTime)
        guard case let .success(state) = viewModel.phase else {
            return XCTFail("Expected success phase")
        }
        XCTAssertEqual(state.notificationPreference, expectedPreference)
        XCTAssertEqual(state.availableAccents, ["parisian", "quebecois"])
        XCTAssertEqual(state.profile.preferredAccent, "parisian")
        XCTAssertEqual(appState.appearancePreference, .dark)
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

    func testUpdatePreferredAccentPersistsProfileSelection() async {
        let progressService = TestProgressService()
        progressService.profileResult = .success(makeProfile(preferredAccent: nil))
        progressService.updateProfileResult = .success(makeProfile(preferredAccent: "quebecois"))
        progressService.availableAccentsResult = .success(["quebecois", "parisian"])
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(progressService: progressService, analytics: analytics)

        await viewModel.load()
        await viewModel.updatePreferredAccent("quebecois")

        XCTAssertEqual(progressService.updateProfileRequests.last?.preferredAccent, "quebecois")
        guard case let .success(state) = viewModel.phase else {
            return XCTFail("Expected success phase")
        }
        XCTAssertEqual(state.profile.preferredAccent, "quebecois")
        XCTAssertEqual(state.availableAccents, ["quebecois", "parisian"])
        XCTAssertEqual(analytics.events.suffix(1).map(\.event), [.settingsUpdated])
        XCTAssertEqual(analytics.events.last?.properties["field"], "preferred_accent")
    }

    func testUpdateAppearancePersistsAndUpdatesAppState() async {
        let progressService = TestProgressService()
        progressService.profileResult = .success(makeProfile(appearancePreference: .system))
        progressService.updateProfileResult = .success(makeProfile(appearancePreference: .dark))
        let analytics = TestAnalyticsService()
        let appState = AppState()
        let viewModel = makeViewModel(
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )

        await viewModel.load()
        await viewModel.updateAppearance(.dark)

        XCTAssertEqual(progressService.updateProfileRequests.last?.appearancePreference, .dark)
        XCTAssertEqual(appState.appearancePreference, .dark)
        XCTAssertEqual(analytics.events.last?.event, .settingsUpdated)
        XCTAssertEqual(analytics.events.last?.properties["field"], "appearance")
    }

    func testDeleteAccountClearsSessionAndUsesDeleteFlow() async {
        let auth = TestAuthService()
        let onboardingService = TestOnboardingService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        appState.session = TestData.session()
        appState.onboardingState = OnboardingState.completed(from: SampleData.profile)
        appState.subscriptionState = SubscriptionState(tier: .premium, isTrial: false, expiresAt: nil)
        appState.selectedTab = .profile
        appState.path = [.settings]
        let viewModel = makeViewModel(
            auth: auth,
            onboardingService: onboardingService,
            analytics: analytics,
            crash: crash,
            appState: appState
        )

        await viewModel.deleteAccount()

        XCTAssertEqual(auth.deleteAccountCallCount, 1)
        XCTAssertEqual(auth.signOutCallCount, 0)
        XCTAssertEqual(onboardingService.savedStates.last, .empty)
        XCTAssertEqual(analytics.events.last?.event, .accountDeleted)
        XCTAssertEqual(analytics.resetCallCount, 1)
        XCTAssertEqual(crash.userSessions, [nil])
        XCTAssertNil(appState.session)
        XCTAssertEqual(appState.onboardingState, .empty)
        XCTAssertEqual(appState.subscriptionState.tier, .free)
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertTrue(appState.path.isEmpty)
    }

    func testLogOutClearsSessionAndNavigation() async {
        let auth = TestAuthService()
        let onboardingService = TestOnboardingService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        appState.session = TestData.session()
        appState.onboardingState = OnboardingState.completed(from: SampleData.profile)
        appState.subscriptionState = SubscriptionState(tier: .premium, isTrial: false, expiresAt: nil)
        appState.selectedTab = .profile
        appState.path = [.settings, .paywall]
        let viewModel = makeViewModel(
            auth: auth,
            onboardingService: onboardingService,
            analytics: analytics,
            crash: crash,
            appState: appState
        )

        await viewModel.logOut()

        XCTAssertEqual(auth.signOutCallCount, 1)
        XCTAssertEqual(onboardingService.savedStates.last, .empty)
        XCTAssertEqual(analytics.resetCallCount, 1)
        XCTAssertEqual(crash.userSessions, [nil])
        XCTAssertNil(appState.session)
        XCTAssertEqual(appState.onboardingState, .empty)
        XCTAssertEqual(appState.subscriptionState.tier, .free)
        XCTAssertEqual(appState.selectedTab, .today)
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
        progressService: TestProgressService = TestProgressService(),
        auth: TestAuthService = TestAuthService(),
        onboardingService: TestOnboardingService = TestOnboardingService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> SettingsViewModel {
        SettingsViewModel(
            notificationService: notificationService,
            progressService: progressService,
            authService: auth,
            onboardingService: onboardingService,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState()
        )
    }

    private func makeProfile(
        preferredAccent: String? = nil,
        dailyLearningMode: DailyLearningMode = .balanced,
        appearancePreference: AppearancePreference = .system
    ) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            email: "settings@example.com",
            displayName: "Settings User",
            activeLanguage: SampleData.french,
            learningGoal: .travel,
            level: .beginner,
            preferredAccent: preferredAccent,
            dailyLearningMode: dailyLearningMode,
            appearancePreference: appearancePreference,
            reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "UTC",
            currentStreakDays: 4,
            bestStreakDays: 9,
            joinedAt: Date(timeIntervalSince1970: 1_690_000_000)
        )
    }
}
