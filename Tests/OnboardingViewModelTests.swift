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

    func testFilteredLanguagesMatchesExpandedSeededLanguageNames() async {
        let onboardingService = TestOnboardingService()
        onboardingService.fetchAvailableLanguagesResult = .success([
            Language(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                code: "de",
                name: "German",
                nativeName: "Deutsch",
                isActive: true
            ),
            Language(
                id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                code: "zh",
                name: "Mandarin",
                nativeName: "Putonghua",
                isActive: true
            ),
            SampleData.french
        ])
        let viewModel = makeViewModel(onboardingService: onboardingService)

        await viewModel.loadAvailableLanguagesIfNeeded()

        viewModel.languageQuery = "Deutsch"
        XCTAssertEqual(viewModel.filteredLanguages.map(\.code), ["de"])

        viewModel.languageQuery = "Mandarin"
        XCTAssertEqual(viewModel.filteredLanguages.map(\.code), ["zh"])
    }

    func testSubmitEmailAuthIdentifiesSessionBeforeCompletionEvents() async {
        let onboardingService = TestOnboardingService()
        let progressService = TestProgressService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        let viewModel = makeViewModel(
            onboardingService: onboardingService,
            progressService: progressService,
            analytics: analytics,
            crash: crash,
            appState: appState
        )
        viewModel.email = "signup@example.com"
        viewModel.password = "secret1"
        viewModel.fullName = "Taylor Example"

        await viewModel.submitEmailAuth()

        XCTAssertEqual(appState.session, TestData.session(email: "signup@example.com"))
        XCTAssertEqual(crash.userSessions, [TestData.session(email: "signup@example.com")])
        XCTAssertEqual(analytics.identifiedSessions, [TestData.session(email: "signup@example.com")])
        XCTAssertEqual(onboardingService.syncedStates.count, 1)
        XCTAssertEqual(analytics.events.map(\.event), [
            .onboardingStarted,
            .authViewOpened,
            .authEmailSignupTapped,
            .authSuccess,
            .signupCompleted,
            .onboardingCompleted
        ])
    }

    func testSubmitEmailLoginRestoresRemoteProfileWithoutSignupEvents() async {
        let onboardingService = TestOnboardingService()
        let progressService = TestProgressService()
        progressService.profileResult = .success(
            UserProfile(
                id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
                email: "returning@example.com",
                displayName: "Returning User",
                activeLanguage: Language(
                    id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
                    code: "ja",
                    name: "Japanese",
                    nativeName: "Nihongo",
                    isActive: true
                ),
                learningGoal: .culture,
                level: .intermediate,
                preferredAccent: "tokyo",
                dailyLearningMode: .reviewFocus,
                appearancePreference: .dark,
                reminderTime: Date(timeIntervalSince1970: 1_700_030_000),
                timezoneIdentifier: "Asia/Tokyo",
                currentStreakDays: 5,
                bestStreakDays: 8,
                joinedAt: Date(timeIntervalSince1970: 1_699_000_000)
            )
        )
        let analytics = TestAnalyticsService()
        let appState = AppState()
        let viewModel = makeViewModel(
            onboardingService: onboardingService,
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )
        viewModel.isCreatingAccount = false
        viewModel.email = "returning@example.com"
        viewModel.password = "secret1"

        await viewModel.submitEmailAuth()

        XCTAssertEqual(appState.session, TestData.session())
        XCTAssertEqual(appState.onboardingState.language?.code, "ja")
        XCTAssertTrue(appState.onboardingState.isCompleted)
        XCTAssertTrue(onboardingService.syncedStates.isEmpty)
        XCTAssertEqual(analytics.events.map(\.event), [
            .onboardingStarted,
            .authViewOpened,
            .authEmailLoginTapped,
            .authSuccess
        ])
    }

    func testLoadNotificationPreviewUsesSelectedLanguage() async {
        let notificationService = TestNotificationService()
        notificationService.preview = NotificationPreview(
            title: "Your Italian word is ready: Ciao",
            body: "Tap to hear it and save it for review."
        )
        let viewModel = makeViewModel(notificationService: notificationService)
        viewModel.onboardingState.language = Language(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            code: "it",
            name: "Italian",
            nativeName: "Italiano",
            isActive: true
        )

        await viewModel.loadNotificationPreviewIfNeeded()

        guard case let .success(preview) = viewModel.notificationPreviewPhase else {
            return XCTFail("Expected preview success phase")
        }
        XCTAssertEqual(preview.title, "Your Italian word is ready: Ciao")
        XCTAssertEqual(preview.body, "Tap to hear it and save it for review.")
    }

    func testSubmitEmailLoginWithoutRemoteProfileKeepsOnboardingIncomplete() async {
        let onboardingService = TestOnboardingService()
        let progressService = TestProgressService()
        progressService.profileResult = .failure(AppError.network("Profile missing."))
        let analytics = TestAnalyticsService()
        let appState = AppState()
        let viewModel = makeViewModel(
            onboardingService: onboardingService,
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )
        viewModel.isCreatingAccount = false
        viewModel.email = "fresh@example.com"
        viewModel.password = "secret1"

        await viewModel.submitEmailAuth()

        XCTAssertEqual(appState.session, TestData.session())
        XCTAssertFalse(appState.onboardingState.isCompleted)
        XCTAssertTrue(onboardingService.syncedStates.isEmpty)
        XCTAssertEqual(analytics.events.map(\.event), [
            .onboardingStarted,
            .authViewOpened,
            .authEmailLoginTapped,
            .authSuccess
        ])
    }

    private func makeViewModel(
        onboardingService: TestOnboardingService = TestOnboardingService(),
        auth: TestAuthService = TestAuthService(),
        progressService: TestProgressService = TestProgressService(),
        notificationService: TestNotificationService = TestNotificationService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> OnboardingViewModel {
        OnboardingViewModel(
            onboardingService: onboardingService,
            authService: auth,
            progressService: progressService,
            notificationService: notificationService,
            analytics: analytics,
            crashReporter: crash,
            appState: appState ?? AppState()
        )
    }
}
