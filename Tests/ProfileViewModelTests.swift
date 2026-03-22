import XCTest
@testable import LinguaDaily

@MainActor
final class ProfileViewModelTests: XCTestCase {
    func testLoadFetchesProfileAndProgressAndUpdatesAppearance() async {
        let progressService = TestProgressService()
        progressService.profileResult = .success(makeProfile(appearance: .dark))
        progressService.progressResult = .success(
            ProgressSnapshot(
                currentStreakDays: 9,
                bestStreakDays: 12,
                wordsLearned: 40,
                masteredCount: 15,
                reviewAccuracy: 0.9,
                weeklyActivity: [],
                bestRetentionCategory: "Verbs"
            )
        )
        let analytics = TestAnalyticsService()
        let appState = AppState()
        let viewModel = makeViewModel(
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )

        await viewModel.load()

        guard case let .success(state) = viewModel.phase else {
            return XCTFail("Expected profile success state")
        }
        XCTAssertEqual(state.profile.displayName, "Profile User")
        XCTAssertEqual(state.progress.wordsLearned, 40)
        XCTAssertEqual(appState.appearancePreference, .dark)
        XCTAssertEqual(analytics.events.map(\.event), [.profileOpened])
    }

    func testBeginEditingProfileLoadsLanguagesAndSeedsEditableFields() async {
        let onboardingService = TestOnboardingService()
        onboardingService.fetchAvailableLanguagesResult = .success([
            SampleData.french,
            Language(
                id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                code: "it",
                name: "Italian",
                nativeName: "Italiano",
                isActive: true
            )
        ])
        let progressService = TestProgressService()
        progressService.profileResult = .success(makeProfile())
        let viewModel = makeViewModel(
            progressService: progressService,
            onboardingService: onboardingService
        )

        await viewModel.load()
        await viewModel.beginEditingProfile()

        XCTAssertTrue(viewModel.isEditingProfile)
        XCTAssertEqual(viewModel.editDisplayName, "Profile User")
        XCTAssertEqual(viewModel.editSelectedLanguage?.code, "fr")
        XCTAssertEqual(viewModel.availableLanguages.map(\.code), ["fr", "it"])
    }

    func testSaveProfilePersistsChangesAndRefreshesAppState() async {
        let progressService = TestProgressService()
        let appState = AppState()
        let analytics = TestAnalyticsService()
        progressService.profileResult = .success(makeProfile())
        progressService.progressResult = .success(
            ProgressSnapshot(
                currentStreakDays: 3,
                bestStreakDays: 8,
                wordsLearned: 10,
                masteredCount: 4,
                reviewAccuracy: 0.8,
                weeklyActivity: [],
                bestRetentionCategory: "Nouns"
            )
        )
        let italian = Language(
            id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
            code: "it",
            name: "Italian",
            nativeName: "Italiano",
            isActive: true
        )
        progressService.updateProfileResult = .success(
            UserProfile(
                id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                email: "profile@example.com",
                displayName: "Taylor Example",
                activeLanguage: italian,
                learningGoal: .culture,
                level: .intermediate,
                preferredAccent: "rome",
                dailyLearningMode: .balanced,
                appearancePreference: .light,
                reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
                timezoneIdentifier: "UTC",
                currentStreakDays: 3,
                bestStreakDays: 8,
                joinedAt: Date(timeIntervalSince1970: 1_690_000_000)
            )
        )

        let viewModel = makeViewModel(
            progressService: progressService,
            analytics: analytics,
            appState: appState
        )

        await viewModel.load()
        await viewModel.beginEditingProfile()
        viewModel.editDisplayName = "Taylor Example"
        viewModel.editSelectedLanguage = italian
        viewModel.editLearningGoal = .culture
        viewModel.editLevel = .intermediate
        await viewModel.saveProfile()

        XCTAssertEqual(progressService.updateProfileRequests.last?.displayName, "Taylor Example")
        XCTAssertEqual(progressService.updateProfileRequests.last?.activeLanguage?.code, "it")
        XCTAssertEqual(progressService.updateProfileRequests.last?.learningGoal, .culture)
        XCTAssertEqual(progressService.updateProfileRequests.last?.level, .intermediate)
        XCTAssertFalse(viewModel.isEditingProfile)
        XCTAssertEqual(appState.onboardingState.language?.code, "it")
        XCTAssertEqual(appState.appearancePreference, .light)
        XCTAssertEqual(analytics.events.last?.event, .profileUpdated)
    }

    private func makeViewModel(
        progressService: TestProgressService = TestProgressService(),
        onboardingService: TestOnboardingService = TestOnboardingService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        appState: AppState? = nil
    ) -> ProfileViewModel {
        ProfileViewModel(
            progressService: progressService,
            onboardingService: onboardingService,
            analytics: analytics,
            crash: TestCrashReportingService(),
            appState: appState ?? AppState()
        )
    }

    private func makeProfile(appearance: AppearancePreference = .system) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            email: "profile@example.com",
            displayName: "Profile User",
            activeLanguage: SampleData.french,
            learningGoal: .travel,
            level: .beginner,
            preferredAccent: "parisian",
            dailyLearningMode: .balanced,
            appearancePreference: appearance,
            reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "UTC",
            currentStreakDays: 6,
            bestStreakDays: 10,
            joinedAt: Date(timeIntervalSince1970: 1_690_000_000)
        )
    }
}
