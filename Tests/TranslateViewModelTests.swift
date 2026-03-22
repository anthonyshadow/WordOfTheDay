import XCTest
import Translation
import UIKit
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

    func testStartVoiceCaptureShowsSettingsErrorWhenSpeechPermissionIsDenied() async {
        let voiceTranslationProvider = TestVoiceTranslationProvider()
        voiceTranslationProvider.permissionState = .speechRecognitionDenied
        let viewModel = makeViewModel(voiceTranslationProvider: voiceTranslationProvider)

        await viewModel.load()
        viewModel.selectedInputMode = .voice
        viewModel.targetLanguage = SampleData.french
        await viewModel.startVoiceCapture()

        XCTAssertEqual(viewModel.translationError?.title, "Speech access needed")
        XCTAssertEqual(viewModel.translationError?.actionTitle, "Open Settings")
        XCTAssertEqual(viewModel.voiceCaptureState, .idle)
    }

    func testVoiceTranslationUsesVoiceInputModeWhenSavingResult() async {
        let translationService = TestTranslationService()
        let voiceTranslationProvider = TestVoiceTranslationProvider()
        voiceTranslationProvider.transcriptUpdatesDuringStart = ["How are you"]
        voiceTranslationProvider.stopResult = .success(
            VoiceTranscriptionResult(
                transcript: "How are you",
                detectedLanguageCode: "en",
                detectionConfidence: 0.88
            )
        )
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "fr-FR")]
        )
        let viewModel = makeViewModel(
            translationService: translationService,
            translationLanguageSupport: translationLanguageSupport,
            voiceTranslationProvider: voiceTranslationProvider
        )

        await viewModel.load()
        viewModel.selectedInputMode = .voice
        viewModel.targetLanguage = SampleData.french

        await viewModel.startVoiceCapture()
        XCTAssertEqual(viewModel.liveVoiceTranscript, "How are you")
        XCTAssertTrue(viewModel.isListeningForVoice)

        await viewModel.stopVoiceCaptureAndTranslate()
        XCTAssertEqual(viewModel.pendingRequest?.text, "How are you")
        XCTAssertEqual(viewModel.pendingRequest?.inputMode, .voice)

        viewModel.handleSuccessfulTranslation(
            sourceText: "How are you",
            translatedText: "Comment ca va ?",
            sourceLanguageIdentifier: "en-US",
            targetLanguageIdentifier: "fr-FR",
            sessionID: "voice-session",
            inputMode: .voice,
            transcriptionText: "How are you",
            detectionConfidence: 0.88
        )

        XCTAssertEqual(viewModel.currentResult?.inputMode, .voice)
        XCTAssertEqual(viewModel.currentResult?.transcriptionText, "How are you")

        await viewModel.toggleSaveForCurrentResult()

        XCTAssertEqual(translationService.createdDrafts.first?.draft.inputMode, .voice)
        XCTAssertEqual(translationService.createdDrafts.first?.draft.transcriptionText, "How are you")
        XCTAssertEqual(translationService.createdDrafts.first?.draft.detectionConfidence, 0.88)
    }

    func testStartCameraCaptureShowsSettingsErrorWhenPermissionIsDenied() async {
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.permissionState = .denied
        let viewModel = makeViewModel(cameraTranslationProvider: cameraTranslationProvider)

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french
        await viewModel.startCameraCapture()

        XCTAssertEqual(viewModel.translationError?.title, "Camera access needed")
        XCTAssertEqual(viewModel.translationError?.actionTitle, "Open Settings")
        XCTAssertFalse(viewModel.isPresentingCameraCapture)
        XCTAssertEqual(viewModel.cameraProcessingState, .idle)
    }

    func testStartCameraCaptureShowsDeviceMessageWhenCameraIsUnavailable() async {
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.isCameraAvailable = false
        cameraTranslationProvider.permissionState = .unavailable
        let viewModel = makeViewModel(cameraTranslationProvider: cameraTranslationProvider)

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french
        await viewModel.startCameraCapture()

        XCTAssertEqual(viewModel.translationError?.title, "Camera requires a device")
        XCTAssertFalse(viewModel.isPresentingCameraCapture)
        XCTAssertEqual(viewModel.cameraProcessingState, .idle)
    }

    func testHandleCapturedCameraImageShowsRetakeErrorWhenNoTextIsDetected() async {
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.extractResult = .failure(CameraTranslationError.noTextDetected)
        let viewModel = makeViewModel(cameraTranslationProvider: cameraTranslationProvider)

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french

        await viewModel.handleCapturedCameraImage(UIImage())

        XCTAssertEqual(viewModel.translationError?.title, "No text found")
        XCTAssertEqual(viewModel.translationError?.actionTitle, "Retake")
        XCTAssertEqual(viewModel.cameraProcessingState, .idle)
        XCTAssertNil(viewModel.pendingRequest)
        XCTAssertNotNil(viewModel.capturedCameraImage)
        XCTAssertEqual(viewModel.extractedCameraText, "")
    }

    func testHandleCapturedCameraImageUsesManualSourceLocaleForOCR() async {
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.extractResult = .success(
            CameraOCRResult(
                extractedText: "Buongiorno",
                detectedLanguageCode: "it",
                detectionConfidence: 0.84
            )
        )
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [
                Locale.Language(identifier: "it-IT"),
                Locale.Language(identifier: "fr-FR")
            ]
        )
        let italian = Language(
            id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
            code: "it",
            name: "Italian",
            nativeName: "Italiano",
            isActive: true
        )
        let viewModel = makeViewModel(
            translationLanguageSupport: translationLanguageSupport,
            cameraTranslationProvider: cameraTranslationProvider
        )

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.sourceSelection = .manual(italian)
        viewModel.targetLanguage = SampleData.french

        await viewModel.handleCapturedCameraImage(UIImage())

        XCTAssertEqual(cameraTranslationProvider.preferredLocaleIdentifiers, ["it"])
        XCTAssertEqual(viewModel.pendingRequest?.sourceLanguageCode, "it")
        XCTAssertNil(viewModel.translationError)
    }

    func testCameraTranslationUsesCameraInputModeWhenSavingResult() async {
        let translationService = TestTranslationService()
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.extractResult = .success(
            CameraOCRResult(
                extractedText: "Buongiorno",
                detectedLanguageCode: "it",
                detectionConfidence: 0.84
            )
        )
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "fr-FR")]
        )
        let viewModel = makeViewModel(
            translationService: translationService,
            translationLanguageSupport: translationLanguageSupport,
            cameraTranslationProvider: cameraTranslationProvider
        )

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french

        await viewModel.startCameraCapture()
        XCTAssertTrue(viewModel.isPresentingCameraCapture)

        await viewModel.handleCapturedCameraImage(UIImage())
        XCTAssertEqual(viewModel.extractedCameraText, "Buongiorno")
        XCTAssertEqual(viewModel.pendingRequest?.text, "Buongiorno")
        XCTAssertEqual(viewModel.pendingRequest?.inputMode, .camera)
        XCTAssertEqual(viewModel.pendingRequest?.extractedText, "Buongiorno")
        XCTAssertFalse(viewModel.isPresentingCameraCapture)

        viewModel.handleSuccessfulTranslation(
            sourceText: "Buongiorno",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "it-IT",
            targetLanguageIdentifier: "fr-FR",
            sessionID: "camera-session",
            inputMode: .camera,
            extractedText: "Buongiorno",
            detectionConfidence: 0.84
        )

        XCTAssertEqual(viewModel.currentResult?.inputMode, .camera)
        XCTAssertEqual(viewModel.currentResult?.extractedText, "Buongiorno")

        await viewModel.toggleSaveForCurrentResult()

        XCTAssertEqual(translationService.createdDrafts.first?.draft.inputMode, .camera)
        XCTAssertEqual(translationService.createdDrafts.first?.draft.extractedText, "Buongiorno")
        XCTAssertEqual(translationService.createdDrafts.first?.draft.detectionConfidence, 0.84)
    }

    func testCameraTranslationResultRemainsTemporaryUntilSaveOrFavorite() async {
        let translationService = TestTranslationService()
        let cameraTranslationProvider = TestCameraTranslationProvider()
        cameraTranslationProvider.extractResult = .success(
            CameraOCRResult(
                extractedText: "Buongiorno",
                detectedLanguageCode: "it",
                detectionConfidence: 0.84
            )
        )
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "fr-FR")]
        )
        let viewModel = makeViewModel(
            translationService: translationService,
            translationLanguageSupport: translationLanguageSupport,
            cameraTranslationProvider: cameraTranslationProvider
        )

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french

        await viewModel.handleCapturedCameraImage(UIImage())
        XCTAssertTrue(translationService.createdDrafts.isEmpty)

        viewModel.handleSuccessfulTranslation(
            sourceText: "Buongiorno",
            translatedText: "Bonjour",
            sourceLanguageIdentifier: "it-IT",
            targetLanguageIdentifier: "fr-FR",
            sessionID: "camera-session",
            inputMode: .camera,
            extractedText: "Buongiorno",
            detectionConfidence: 0.84
        )

        XCTAssertNil(viewModel.currentResult?.savedTranslationID)
        XCTAssertFalse(viewModel.currentResult?.isSaved ?? true)
        XCTAssertFalse(viewModel.currentResult?.isFavorited ?? true)
        XCTAssertTrue(translationService.createdDrafts.isEmpty)
    }

    func testSwitchingAwayFromCameraClearsCameraCaptureState() async {
        let cameraTranslationProvider = TestCameraTranslationProvider()
        let translationLanguageSupport = TestTranslationLanguageSupportProvider(
            languages: [Locale.Language(identifier: "fr-FR")]
        )
        let viewModel = makeViewModel(
            translationLanguageSupport: translationLanguageSupport,
            cameraTranslationProvider: cameraTranslationProvider
        )

        await viewModel.load()
        viewModel.selectedInputMode = .camera
        viewModel.targetLanguage = SampleData.french

        await viewModel.handleCapturedCameraImage(UIImage())
        XCTAssertNotNil(viewModel.capturedCameraImage)
        XCTAssertEqual(viewModel.extractedCameraText, "Bonjour")

        viewModel.selectedInputMode = .text

        XCTAssertNil(viewModel.capturedCameraImage)
        XCTAssertEqual(viewModel.extractedCameraText, "")
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
        translationLanguageSupport: TestTranslationLanguageSupportProvider = TestTranslationLanguageSupportProvider(),
        voiceTranslationProvider: TestVoiceTranslationProvider = TestVoiceTranslationProvider(),
        cameraTranslationProvider: TestCameraTranslationProvider = TestCameraTranslationProvider()
    ) -> TranslateViewModel {
        TranslateViewModel(
            onboardingService: onboardingService,
            translationService: translationService,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState(),
            translationLanguageSupport: translationLanguageSupport,
            voiceTranslationProvider: voiceTranslationProvider,
            cameraTranslationProvider: cameraTranslationProvider
        )
    }
}
