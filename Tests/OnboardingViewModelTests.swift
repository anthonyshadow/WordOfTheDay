import XCTest
@testable import LinguaDaily

@MainActor
final class OnboardingViewModelTests: XCTestCase {
    func testLoadAvailableLanguagesReconcilesStoredSelectionToSupabaseLanguage() async {
        let onboardingService = TestOnboardingService()
        let storedFrench = Language(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            code: "fr",
            name: "French",
            nativeName: "Francais",
            isActive: true
        )
        let supabaseFrench = Language(
            id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            code: "fr",
            name: "French",
            nativeName: "Francais",
            isActive: true
        )
        onboardingService.storedState = OnboardingState(
            goal: .travel,
            language: storedFrench,
            level: nil,
            reminderTime: nil,
            hasSeenNotificationEducation: false,
            hasRequestedNotificationPermission: false,
            isCompleted: false
        )
        onboardingService.fetchAvailableLanguagesResult = .success([
            supabaseFrench,
            Language(
                id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
                code: "es",
                name: "Spanish",
                nativeName: "Espanol",
                isActive: true
            )
        ])

        let appState = AppState()
        let viewModel = makeViewModel(onboardingService: onboardingService, appState: appState)

        await viewModel.loadAvailableLanguagesIfNeeded()

        XCTAssertEqual(viewModel.availableLanguages.map(\.code), ["fr", "es"])
        XCTAssertEqual(viewModel.onboardingState.language?.id, supabaseFrench.id)
        XCTAssertEqual(appState.onboardingState.language?.id, supabaseFrench.id)
        XCTAssertEqual(onboardingService.savedStates.last?.language?.id, supabaseFrench.id)
        XCTAssertEqual(onboardingService.fetchAvailableLanguagesCallCount, 1)
        viewModel.step = .language
        XCTAssertTrue(viewModel.canContinue)
    }

    func testLoadAvailableLanguagesClearsUnavailableStoredSelection() async {
        let onboardingService = TestOnboardingService()
        onboardingService.storedState = OnboardingState(
            goal: .travel,
            language: Language(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                code: "ja",
                name: "Japanese",
                nativeName: "Nihongo",
                isActive: true
            ),
            level: nil,
            reminderTime: nil,
            hasSeenNotificationEducation: false,
            hasRequestedNotificationPermission: false,
            isCompleted: false
        )
        onboardingService.fetchAvailableLanguagesResult = .success([SampleData.french])
        let appState = AppState()
        let viewModel = makeViewModel(onboardingService: onboardingService, appState: appState)

        await viewModel.loadAvailableLanguagesIfNeeded()

        XCTAssertNil(viewModel.onboardingState.language)
        XCTAssertNil(appState.onboardingState.language)
        XCTAssertNil(onboardingService.savedStates.last?.language)
    }

    func testLoadAvailableLanguagesFailureMapsViewErrorAndCapturesCrash() async {
        let onboardingService = TestOnboardingService()
        onboardingService.fetchAvailableLanguagesResult = .failure(AppError.network("Could not load languages."))
        let crash = TestCrashReportingService()
        let viewModel = makeViewModel(onboardingService: onboardingService, crash: crash)

        await viewModel.loadAvailableLanguagesIfNeeded()

        XCTAssertEqual(crash.contexts, [["feature": "onboarding_languages"]])
        guard case let .failure(error) = viewModel.languagePhase else {
            return XCTFail("Expected language failure phase")
        }
        XCTAssertEqual(error.title, "Network issue")
        XCTAssertEqual(error.message, "Could not load languages.")
        XCTAssertEqual(error.actionTitle, "Retry")
    }

    func testSubmitEmailAuthIdentifiesSessionBeforeCompletionEvents() async {
        let onboardingService = TestOnboardingService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        let viewModel = makeViewModel(
            onboardingService: onboardingService,
            analytics: analytics,
            crash: crash,
            appState: appState
        )
        viewModel.email = "signup@example.com"
        viewModel.password = "secret1"

        await viewModel.submitEmailAuth()

        XCTAssertEqual(appState.session, TestData.session(email: "signup@example.com"))
        XCTAssertEqual(crash.userSessions, [TestData.session(email: "signup@example.com")])
        XCTAssertEqual(analytics.identifiedSessions, [TestData.session(email: "signup@example.com")])
        XCTAssertEqual(analytics.events.map(\.event), [
            .onboardingStarted,
            .authViewOpened,
            .authEmailSignupTapped,
            .authSuccess,
            .signupCompleted,
            .onboardingCompleted
        ])
    }

    private func makeViewModel(
        onboardingService: TestOnboardingService = TestOnboardingService(),
        auth: TestAuthService = TestAuthService(),
        notificationService: TestNotificationService = TestNotificationService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            onboardingService: onboardingService,
            authService: auth,
            notificationService: notificationService,
            analytics: analytics,
            crashReporter: crash,
            appState: appState ?? AppState()
        )
    }
}
