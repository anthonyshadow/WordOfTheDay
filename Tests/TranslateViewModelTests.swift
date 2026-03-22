import XCTest
import Translation
@testable import LinguaDaily

@MainActor
final class TranslateViewModelTests: XCTestCase {
    func testLoadDefaultsTargetLanguageFromAppStateSelection() async {
        let onboardingService = TestOnboardingService()
        let spanish = Language(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            code: "es",
            name: "Spanish",
            nativeName: "Espanol",
            isActive: true
        )
        onboardingService.fetchAvailableLanguagesResult = .success([SampleData.french, spanish])
        let analytics = TestAnalyticsService()
        let appState = AppState()
        appState.onboardingState.language = spanish

        let viewModel = makeViewModel(
            onboardingService: onboardingService,
            analytics: analytics,
            appState: appState
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.targetLanguage?.code, "es")
        guard case let .success(languages) = viewModel.languagePhase else {
            return XCTFail("Expected loaded languages")
        }
        XCTAssertEqual(languages.map(\.code), ["fr", "es"])
        XCTAssertEqual(analytics.events.map(\.event), [.translateOpened])
    }

    func testRequestTranslationValidatesMatchingManualSourceAndTarget() {
        let viewModel = makeViewModel()
        viewModel.targetLanguage = SampleData.french
        viewModel.sourceSelection = .manual(SampleData.french)
        viewModel.inputText = "Hello"

        viewModel.requestTranslation()

        XCTAssertFalse(viewModel.isTranslating)
        XCTAssertNil(viewModel.pendingRequest)
        XCTAssertEqual(viewModel.translationError?.title, "Invalid input")
        XCTAssertEqual(viewModel.translationError?.message, "Choose different source and target languages.")
    }

    func testRequestTranslationCreatesPendingRequestAndTracksAnalytics() async {
        let analytics = TestAnalyticsService()
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "fr-FR")]
        )
        let viewModel = makeViewModel(
            analytics: analytics,
            translationLanguageSupport: translationLanguageSupport
        )

        await viewModel.load()
        viewModel.targetLanguage = SampleData.french
        viewModel.inputText = "Hello"

        viewModel.requestTranslation()

        XCTAssertTrue(viewModel.isTranslating)
        XCTAssertEqual(viewModel.pendingRequest?.text, "Hello")
        XCTAssertEqual(viewModel.pendingRequest?.sourceLanguageCode, nil)
        XCTAssertEqual(viewModel.pendingRequest?.targetLanguageCode, "fr")
        XCTAssertEqual(viewModel.translationConfiguration?.target, Locale.Language(identifier: "fr-FR"))
        XCTAssertEqual(analytics.events.last?.event, .translateRequested)
    }

    func testRequestTranslationResolvesSupportedLanguageVariantsBeforeConfiguringSession() async {
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "it-IT")]
        )
        let viewModel = makeViewModel(translationLanguageSupport: translationLanguageSupport)

        await viewModel.load()
        viewModel.targetLanguage = Language(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            code: "it",
            name: "Italian",
            nativeName: "Italiano",
            isActive: true
        )
        viewModel.inputText = "Hello"

        viewModel.requestTranslation()

        XCTAssertTrue(viewModel.isTranslating)
        XCTAssertEqual(viewModel.translationConfiguration?.target, Locale.Language(identifier: "it-IT"))
        XCTAssertNil(viewModel.translationError)
    }

    func testRequestTranslationShowsHelpfulErrorWhenTranslationFrameworkIsUnavailable() async {
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            isSimulatorEnvironment: true,
            languages: []
        )
        let viewModel = makeViewModel(translationLanguageSupport: translationLanguageSupport)

        await viewModel.load()
        viewModel.targetLanguage = SampleData.french
        viewModel.inputText = "Hello"

        viewModel.requestTranslation()

        XCTAssertFalse(viewModel.isTranslating)
        XCTAssertEqual(viewModel.translationError?.title, "Translation requires a device")
        XCTAssertEqual(
            viewModel.translationError?.message,
            "Apple's Translation framework isn't available in the iOS Simulator. Run LinguaDaily on a physical iPhone or iPad to translate text."
        )
    }

    func testHandleSuccessfulTranslationCreatesUnsavedResultAndTracksSuccess() {
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(analytics: analytics)

        viewModel.handleSuccessfulTranslation(
            sourceText: "Hello",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "en-US",
            targetLanguageIdentifier: "fr-FR",
            sessionID: "session-1"
        )

        XCTAssertEqual(viewModel.currentResult?.sourceText, "Hello")
        XCTAssertEqual(viewModel.currentResult?.translatedText, "Bonjour")
        XCTAssertEqual(viewModel.currentResult?.sourceLanguage, "en")
        XCTAssertEqual(viewModel.currentResult?.targetLanguage, "fr")
        XCTAssertFalse(viewModel.currentResult?.isSaved ?? true)
        XCTAssertEqual(analytics.events.last?.event, .translateSucceeded)
    }

    func testToggleFavoriteCreatesSavedTranslationWhenUnsaved() async {
        let translationService = TestTranslationService()
        let savedTranslation = TestData.savedTranslation(isFavorited: true)
        translationService.createResult = .success(savedTranslation)
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(
            translationService: translationService,
            analytics: analytics
        )
        viewModel.handleSuccessfulTranslation(
            sourceText: "Hello",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "fr",
            sessionID: "session-1"
        )

        await viewModel.toggleFavoriteForCurrentResult()

        XCTAssertEqual(translationService.createdDrafts.count, 1)
        XCTAssertTrue(translationService.createdDrafts.first?.isFavorited ?? false)
        XCTAssertEqual(viewModel.currentResult?.savedTranslationID, savedTranslation.id)
        XCTAssertTrue(viewModel.currentResult?.isFavorited ?? false)
        XCTAssertEqual(analytics.events.last?.event, .translationFavorited)
    }

    func testToggleSaveDeletesFavoritedResultAndClearsFlags() async {
        let translationService = TestTranslationService()
        let savedTranslation = TestData.savedTranslation(isFavorited: true)
        translationService.createResult = .success(savedTranslation)
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(
            translationService: translationService,
            analytics: analytics
        )
        viewModel.handleSuccessfulTranslation(
            sourceText: "Hello",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "fr",
            sessionID: "session-1"
        )

        await viewModel.toggleFavoriteForCurrentResult()
        await viewModel.toggleSaveForCurrentResult()

        XCTAssertEqual(translationService.deletedIDs, [savedTranslation.id])
        XCTAssertFalse(viewModel.currentResult?.isSaved ?? true)
        XCTAssertFalse(viewModel.currentResult?.isFavorited ?? true)
        XCTAssertEqual(analytics.events.last?.event, .translationRemoved)
    }

    func testToggleSaveFailureSurfacesErrorAndCapturesCrash() async {
        let translationService = TestTranslationService()
        translationService.createResult = .failure(AppError.network("Could not save translation."))
        let crash = TestCrashReportingService()
        let viewModel = makeViewModel(
            translationService: translationService,
            crash: crash
        )
        viewModel.handleSuccessfulTranslation(
            sourceText: "Hello",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "en",
            targetLanguageIdentifier: "fr",
            sessionID: "session-1"
        )

        await viewModel.toggleSaveForCurrentResult()

        XCTAssertEqual(crash.contexts, [["feature": "translate_toggle_save"]])
        XCTAssertEqual(viewModel.translationError?.title, "Network issue")
        XCTAssertEqual(viewModel.translationError?.message, "Could not save translation.")
        XCTAssertFalse(viewModel.currentResult?.isSaved ?? true)
    }

    private func makeViewModel(
        onboardingService: TestOnboardingService = TestOnboardingService(),
        translationService: TestTranslationService = TestTranslationService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil,
        translationLanguageSupport: TestTranslationLanguageSupportProvider = TestTranslationLanguageSupportProvider()
    ) -> TranslateViewModel {
        TranslateViewModel(
            onboardingService: onboardingService,
            translationService: translationService,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState(),
            translationLanguageSupport: translationLanguageSupport
        )
    }
}
