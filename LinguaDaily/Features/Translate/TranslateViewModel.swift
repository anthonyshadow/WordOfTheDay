import AVFoundation
import Foundation
import Combine
import NaturalLanguage
import Speech
import Translation
import UIKit

protocol TranslationLanguageSupportProviding {
    var isSimulatorEnvironment: Bool { get }
    func supportedLanguages() async -> [Locale.Language]
}

struct SystemTranslationLanguageSupportProvider: TranslationLanguageSupportProviding {
    private let availability = LanguageAvailability()

    var isSimulatorEnvironment: Bool {
        #if targetEnvironment(simulator)
        true
        #else
        false
        #endif
    }

    func supportedLanguages() async -> [Locale.Language] {
        await availability.supportedLanguages
    }
}

enum VoiceTranslationPermissionState: Equatable {
    case authorized
    case microphoneDenied
    case speechRecognitionDenied
    case unavailable
}

enum VoiceTranslationCaptureState: Equatable {
    case idle
    case requestingPermission
    case listening
    case processing
}

struct VoiceTranscriptionResult: Equatable {
    let transcript: String
    let detectedLanguageCode: String?
    let detectionConfidence: Double?
}

protocol VoiceTranslationProviding {
    func requestPermissionsIfNeeded() async -> VoiceTranslationPermissionState
    func startTranscribing(
        localeIdentifier: String?,
        onUpdate: @escaping @MainActor @Sendable (String) -> Void
    ) async throws
    func stopTranscribing() async throws -> VoiceTranscriptionResult
    func cancelTranscribing() async
}

private enum VoiceTranslationError: Error {
    case microphonePermissionDenied
    case speechRecognitionPermissionDenied
    case recognitionUnavailable
    case audioSessionUnavailable
    case noSpeechDetected
}

final class SystemVoiceTranslationProvider: VoiceTranslationProviding {
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var latestTranscript = ""
    private var latestRecognitionError: Error?

    func requestPermissionsIfNeeded() async -> VoiceTranslationPermissionState {
        guard await requestMicrophonePermission() else {
            return .microphoneDenied
        }

        let speechAuthorizationStatus = await requestSpeechRecognitionAuthorization()
        switch speechAuthorizationStatus {
        case .authorized:
            return .authorized
        case .denied:
            return .speechRecognitionDenied
        case .restricted, .notDetermined:
            return .unavailable
        @unknown default:
            return .unavailable
        }
    }

    func startTranscribing(
        localeIdentifier: String?,
        onUpdate: @escaping @MainActor @Sendable (String) -> Void
    ) async throws {
        await cancelTranscribing()

        guard let recognizer = makeSpeechRecognizer(localeIdentifier: localeIdentifier),
              recognizer.isAvailable else {
            throw VoiceTranslationError.recognitionUnavailable
        }

        let audioEngine = AVAudioEngine()
        let recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        recognitionRequest.shouldReportPartialResults = true
        latestTranscript = ""
        latestRecognitionError = nil

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            throw VoiceTranslationError.audioSessionUnavailable
        }

        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.removeTap(onBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        self.audioEngine = audioEngine
        self.recognitionRequest = recognitionRequest
        self.recognitionTask = recognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self else {
                return
            }

            if let result {
                let transcript = result.bestTranscription.formattedString.trimmingCharacters(in: .whitespacesAndNewlines)
                latestTranscript = transcript
                Task { @MainActor in
                    onUpdate(transcript)
                }
            }

            if let error {
                latestRecognitionError = error
            }
        }

        audioEngine.prepare()
        do {
            try audioEngine.start()
        } catch {
            await cancelTranscribing()
            throw VoiceTranslationError.audioSessionUnavailable
        }
    }

    func stopTranscribing() async throws -> VoiceTranscriptionResult {
        recognitionRequest?.endAudio()
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        try? await Task.sleep(for: .milliseconds(400))

        let transcript = latestTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
        let detection = Self.detectLanguage(for: transcript)
        let recognitionError = latestRecognitionError
        await cancelTranscribing()

        guard !transcript.isEmpty else {
            if let recognitionError {
                throw recognitionError
            }
            throw VoiceTranslationError.noSpeechDetected
        }

        return VoiceTranscriptionResult(
            transcript: transcript,
            detectedLanguageCode: detection.languageCode,
            detectionConfidence: detection.confidence
        )
    }

    func cancelTranscribing() async {
        recognitionTask?.cancel()
        recognitionTask = nil
        recognitionRequest = nil
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine = nil
        latestTranscript = ""
        latestRecognitionError = nil

        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }

    private func makeSpeechRecognizer(localeIdentifier: String?) -> SFSpeechRecognizer? {
        if let localeIdentifier,
           let recognizer = SFSpeechRecognizer(locale: Locale(identifier: localeIdentifier)) {
            return recognizer
        }

        if let preferredLocaleIdentifier = Locale.preferredLanguages.first,
           let recognizer = SFSpeechRecognizer(locale: Locale(identifier: preferredLocaleIdentifier)) {
            return recognizer
        }

        return SFSpeechRecognizer()
    }

    private func requestMicrophonePermission() async -> Bool {
        await withCheckedContinuation { continuation in
            AVAudioSession.sharedInstance().requestRecordPermission { granted in
                continuation.resume(returning: granted)
            }
        }
    }

    private func requestSpeechRecognitionAuthorization() async -> SFSpeechRecognizerAuthorizationStatus {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status)
            }
        }
    }

    private static func detectLanguage(for transcript: String) -> (languageCode: String?, confidence: Double?) {
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTranscript.isEmpty else {
            return (nil, nil)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmedTranscript)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let detectedLanguage = hypotheses.first else {
            return (nil, nil)
        }

        return (detectedLanguage.key.rawValue, detectedLanguage.value)
    }
}

struct TranslationExecutionRequest: Equatable {
    let id: UUID
    let text: String
    let sourceLanguageCode: String?
    let targetLanguageCode: String
    let inputMode: TranslationInputMode
    let transcriptionText: String?
    let extractedText: String?
    let detectionConfidence: Double?
}

@MainActor
final class TranslateViewModel: ObservableObject {
    @Published var languagePhase: AsyncPhase<[Language]> = .idle
    @Published var selectedInputMode: TranslationInputMode = .text {
        didSet {
            guard selectedInputMode != oldValue else {
                return
            }

            if oldValue == .voice {
                Task { await cancelVoiceCapture() }
            }

            currentResult = nil
            clearTranslationError()
            if selectedInputMode != .voice {
                liveVoiceTranscript = ""
                voiceCaptureState = .idle
            }
        }
    }
    @Published var inputText = "" {
        didSet {
            if normalizedInputText != currentResult?.sourceText {
                currentResult = nil
            }
            clearTranslationError()
        }
    }
    @Published var sourceSelection: TranslationSourceSelection = .autoDetect {
        didSet {
            currentResult = nil
            clearTranslationError()
        }
    }
    @Published var targetLanguage: Language? {
        didSet {
            currentResult = nil
            clearTranslationError()
        }
    }
    @Published private(set) var currentResult: TextTranslationResult?
    @Published private(set) var translationError: ViewError?
    @Published private(set) var isTranslating = false
    @Published private(set) var isSavingResult = false
    @Published private(set) var pendingRequest: TranslationExecutionRequest?
    @Published private(set) var translationConfiguration: TranslationSession.Configuration?
    @Published private(set) var voiceCaptureState: VoiceTranslationCaptureState = .idle
    @Published private(set) var liveVoiceTranscript = ""
    @Published var isPresentingSavedLibrary = false

    private let onboardingService: OnboardingServiceProtocol
    private let translationService: TranslationServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState
    private let translationLanguageSupport: TranslationLanguageSupportProviding
    private let voiceTranslationProvider: VoiceTranslationProviding
    private var supportedTranslationLanguages: [Locale.Language] = []
    private var errorAction: TranslateErrorAction = .clear

    init(
        onboardingService: OnboardingServiceProtocol,
        translationService: TranslationServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        appState: AppState,
        translationLanguageSupport: TranslationLanguageSupportProviding = SystemTranslationLanguageSupportProvider(),
        voiceTranslationProvider: VoiceTranslationProviding = SystemVoiceTranslationProvider()
    ) {
        self.onboardingService = onboardingService
        self.translationService = translationService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
        self.translationLanguageSupport = translationLanguageSupport
        self.voiceTranslationProvider = voiceTranslationProvider
    }

    var availableLanguages: [Language] {
        guard case let .success(languages) = languagePhase else {
            return []
        }
        return languages
    }

    var normalizedInputText: String {
        inputText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var canTranslate: Bool {
        !normalizedInputText.isEmpty && targetLanguage != nil && !isTranslating
    }

    var canStartVoiceCapture: Bool {
        targetLanguage != nil && !isTranslating && voiceCaptureState == .idle
    }

    var isListeningForVoice: Bool {
        voiceCaptureState == .listening
    }

    var isProcessingVoiceCapture: Bool {
        voiceCaptureState == .requestingPermission || voiceCaptureState == .processing
    }

    var canSwapLanguages: Bool {
        guard let targetLanguage else {
            return false
        }

        if let sourceLanguage = sourceSelection.language {
            return sourceLanguage.code != targetLanguage.code
        }

        guard let currentResult else {
            return false
        }

        let detectedSourceCode = Self.minimalLanguageIdentifier(from: currentResult.sourceLanguage)
        return availableLanguages.contains(where: { $0.code == detectedSourceCode })
            && detectedSourceCode != targetLanguage.code
    }

    func load() async {
        if case .success = languagePhase {
            return
        }

        languagePhase = .loading

        do {
            async let availableLanguagesTask = onboardingService.fetchAvailableLanguages()
            async let supportedTranslationLanguagesTask = translationLanguageSupport.supportedLanguages()

            let languages = try await availableLanguagesTask
            supportedTranslationLanguages = await supportedTranslationLanguagesTask
            guard !languages.isEmpty else {
                languagePhase = .empty
                return
            }

            let preferredLanguageCode = appState.onboardingState.language?.code
            targetLanguage = languages.first(where: { $0.code == preferredLanguageCode }) ?? languages.first

            if let selectedSourceCode = sourceSelection.language?.code,
               let matchingSource = languages.first(where: { $0.code == selectedSourceCode }) {
                sourceSelection = .manual(matchingSource)
            } else if sourceSelection.language != nil {
                sourceSelection = .autoDetect
            }

            languagePhase = .success(languages)
            analytics.track(
                .translateOpened,
                properties: [
                    "available_languages": "\(languages.count)",
                    "default_target": targetLanguage?.code ?? "none"
                ]
            )
        } catch {
            crash.capture(error, context: ["feature": "translate_load_languages"])
            languagePhase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func requestTranslation() {
        switch selectedInputMode {
        case .text:
            requestTranslation(
                inputMode: .text,
                text: normalizedInputText,
                transcriptionText: nil,
                extractedText: nil,
                detectionConfidence: nil
            )
        case .voice:
            requestTranslation(
                inputMode: .voice,
                text: liveVoiceTranscript,
                transcriptionText: liveVoiceTranscript,
                extractedText: nil,
                detectionConfidence: nil
            )
        case .camera:
            break
        }
    }

    func startVoiceCapture() async {
        clearTranslationError()
        currentResult = nil
        liveVoiceTranscript = ""
        voiceCaptureState = .requestingPermission

        let permissionState = await voiceTranslationProvider.requestPermissionsIfNeeded()
        switch permissionState {
        case .authorized:
            break
        case .microphoneDenied:
            voiceCaptureState = .idle
            presentError(
                ViewError(
                    title: "Microphone access needed",
                    message: "Allow microphone access in Settings before starting voice translation.",
                    actionTitle: "Open Settings"
                ),
                action: .openSettings
            )
            return
        case .speechRecognitionDenied:
            voiceCaptureState = .idle
            presentError(
                ViewError(
                    title: "Speech access needed",
                    message: "Allow speech recognition in Settings before starting voice translation.",
                    actionTitle: "Open Settings"
                ),
                action: .openSettings
            )
            return
        case .unavailable:
            voiceCaptureState = .idle
            presentError(
                ViewError(
                    title: "Voice translation unavailable",
                    message: "Speech recognition isn't available on this device right now.",
                    actionTitle: "OK"
                ),
                action: .clear
            )
            return
        }

        do {
            try await voiceTranslationProvider.startTranscribing(
                localeIdentifier: preferredVoiceRecognizerLocaleIdentifier()
            ) { [weak self] transcript in
                self?.liveVoiceTranscript = transcript
            }
            voiceCaptureState = .listening
        } catch {
            voiceCaptureState = .idle
            presentVoiceCaptureError(error)
        }
    }

    func stopVoiceCaptureAndTranslate() async {
        guard voiceCaptureState == .listening else {
            return
        }

        voiceCaptureState = .processing

        do {
            let transcription = try await voiceTranslationProvider.stopTranscribing()
            liveVoiceTranscript = transcription.transcript
            voiceCaptureState = .idle
            requestTranslation(
                inputMode: .voice,
                text: transcription.transcript,
                transcriptionText: transcription.transcript,
                extractedText: nil,
                detectionConfidence: transcription.detectionConfidence
            )
        } catch {
            voiceCaptureState = .idle
            presentVoiceCaptureError(error)
        }
    }

    func cancelVoiceCapture() async {
        await voiceTranslationProvider.cancelTranscribing()
        voiceCaptureState = .idle
        liveVoiceTranscript = ""
    }

    func clearVoiceTranscript() {
        liveVoiceTranscript = ""
        currentResult = nil
        clearTranslationError()
    }

    private func requestTranslation(
        inputMode: TranslationInputMode,
        text: String,
        transcriptionText: String?,
        extractedText: String?,
        detectionConfidence: Double?
    ) {
        guard let targetLanguage else {
            presentError(
                AppError.validation("Choose a target language before translating.").viewError,
                action: .clear
            )
            return
        }

        let trimmedInput = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedInput.isEmpty else {
            presentError(
                AppError.validation("Enter a word, phrase, or sentence to translate.").viewError,
                action: .clear
            )
            return
        }

        if let sourceLanguage = sourceSelection.language,
           sourceLanguage.code == targetLanguage.code {
            presentError(
                AppError.validation("Choose different source and target languages.").viewError,
                action: .clear
            )
            return
        }

        guard !supportedTranslationLanguages.isEmpty else {
            presentError(
                translationUnavailableError(),
                action: .clear
            )
            return
        }

        guard let resolvedTargetLanguage = resolvedTranslationLanguage(for: targetLanguage.code) else {
            presentError(
                unsupportedTranslationLanguageError(for: targetLanguage.name),
                action: .clear
            )
            return
        }

        let resolvedSourceLanguage: Locale.Language?
        if let sourceLanguage = sourceSelection.language {
            guard let resolvedLanguage = resolvedTranslationLanguage(for: sourceLanguage.code) else {
                presentError(
                    unsupportedTranslationLanguageError(for: sourceLanguage.name),
                    action: .clear
                )
                return
            }
            resolvedSourceLanguage = resolvedLanguage
        } else {
            resolvedSourceLanguage = nil
        }

        clearTranslationError()
        isTranslating = true

        let request = TranslationExecutionRequest(
            id: UUID(),
            text: trimmedInput,
            sourceLanguageCode: sourceSelection.language?.code,
            targetLanguageCode: targetLanguage.code,
            inputMode: inputMode,
            transcriptionText: transcriptionText,
            extractedText: extractedText,
            detectionConfidence: detectionConfidence
        )
        pendingRequest = request

        var configuration = TranslationSession.Configuration(
            source: resolvedSourceLanguage,
            target: resolvedTargetLanguage
        )
        if let previousConfiguration = translationConfiguration,
           previousConfiguration.source == configuration.source,
           previousConfiguration.target == configuration.target {
            configuration.invalidate()
        }
        translationConfiguration = configuration

        analytics.track(
            .translateRequested,
            properties: [
                "input_mode": inputMode.rawValue,
                "source_language": request.sourceLanguageCode ?? "auto",
                "target_language": request.targetLanguageCode,
                "text_length": "\(trimmedInput.count)"
            ]
        )
    }

    func performTranslation(using session: TranslationSession) async {
        guard let request = pendingRequest else {
            return
        }

        do {
            try await session.prepareTranslation()
            let response = try await session.translate(request.text)
            handleSuccessfulTranslation(
                sourceText: response.sourceText,
                translatedText: response.targetText,
                sourceLanguageIdentifier: response.sourceLanguage.minimalIdentifier,
                targetLanguageIdentifier: response.targetLanguage.minimalIdentifier,
                sessionID: request.id.uuidString,
                inputMode: request.inputMode,
                transcriptionText: request.transcriptionText,
                extractedText: request.extractedText,
                detectionConfidence: request.detectionConfidence
            )
        } catch {
            handleTranslationFailure(error)
        }
    }

    func handleSuccessfulTranslation(
        sourceText: String,
        translatedText: String,
        sourceLanguageIdentifier: String,
        targetLanguageIdentifier: String,
        sessionID: String?,
        inputMode: TranslationInputMode = .text,
        transcriptionText: String? = nil,
        extractedText: String? = nil,
        detectionConfidence: Double? = nil
    ) {
        isTranslating = false
        pendingRequest = nil
        clearTranslationError()
        currentResult = TextTranslationResult(
            inputMode: inputMode,
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: Self.minimalLanguageIdentifier(from: sourceLanguageIdentifier),
            targetLanguage: Self.minimalLanguageIdentifier(from: targetLanguageIdentifier),
            transcriptionText: transcriptionText,
            extractedText: extractedText,
            detectionConfidence: detectionConfidence,
            sessionID: sessionID
        )
        analytics.track(
            .translateSucceeded,
            properties: [
                "input_mode": inputMode.rawValue,
                "source_language": Self.minimalLanguageIdentifier(from: sourceLanguageIdentifier),
                "target_language": Self.minimalLanguageIdentifier(from: targetLanguageIdentifier)
            ]
        )
    }

    func clearInput() {
        inputText = ""
        currentResult = nil
        clearTranslationError()
    }

    func swapLanguages() {
        guard let targetLanguage else {
            return
        }

        if let sourceLanguage = sourceSelection.language {
            sourceSelection = .manual(targetLanguage)
            self.targetLanguage = sourceLanguage
            return
        }

        guard let currentResult else {
            return
        }

        let detectedSourceCode = Self.minimalLanguageIdentifier(from: currentResult.sourceLanguage)
        guard let detectedSource = availableLanguages.first(where: { $0.code == detectedSourceCode }) else {
            return
        }

        sourceSelection = .manual(targetLanguage)
        self.targetLanguage = detectedSource
    }

    func toggleSaveForCurrentResult() async {
        guard var result = currentResult else {
            return
        }

        isSavingResult = true
        defer { isSavingResult = false }

        do {
            if let savedTranslationID = result.savedTranslationID {
                try await translationService.deleteSavedTranslation(id: savedTranslationID)
                result.savedTranslationID = nil
                result.isFavorited = false
                currentResult = result
                analytics.track(
                    .translationRemoved,
                    properties: translationAnalyticsProperties(
                        sourceLanguage: result.sourceLanguage,
                        targetLanguage: result.targetLanguage,
                        inputMode: result.inputMode
                    )
                )
            } else {
                let savedTranslation = try await translationService.createSavedTranslation(
                    from: result.draft,
                    isFavorited: false
                )
                result.savedTranslationID = savedTranslation.id
                result.isFavorited = savedTranslation.isFavorited
                currentResult = result
                analytics.track(
                    .translationSaved,
                    properties: translationAnalyticsProperties(
                        sourceLanguage: savedTranslation.sourceLanguage,
                        targetLanguage: savedTranslation.targetLanguage,
                        inputMode: savedTranslation.inputMode
                    )
                )
            }
        } catch {
            crash.capture(error, context: ["feature": "translate_toggle_save"])
            presentError((error as? AppError)?.viewError ?? .generic, action: .clear)
        }
    }

    func toggleFavoriteForCurrentResult() async {
        guard var result = currentResult else {
            return
        }

        isSavingResult = true
        defer { isSavingResult = false }

        do {
            if let savedTranslationID = result.savedTranslationID {
                let updatedTranslation = try await translationService.updateSavedTranslation(
                    id: savedTranslationID,
                    isFavorited: !result.isFavorited
                )
                result.savedTranslationID = updatedTranslation.id
                result.isFavorited = updatedTranslation.isFavorited
                currentResult = result
                analytics.track(
                    updatedTranslation.isFavorited ? .translationFavorited : .translationUnfavorited,
                    properties: translationAnalyticsProperties(
                        sourceLanguage: updatedTranslation.sourceLanguage,
                        targetLanguage: updatedTranslation.targetLanguage,
                        inputMode: updatedTranslation.inputMode
                    )
                )
            } else {
                let savedTranslation = try await translationService.createSavedTranslation(
                    from: result.draft,
                    isFavorited: true
                )
                result.savedTranslationID = savedTranslation.id
                result.isFavorited = savedTranslation.isFavorited
                currentResult = result
                analytics.track(
                    .translationFavorited,
                    properties: translationAnalyticsProperties(
                        sourceLanguage: savedTranslation.sourceLanguage,
                        targetLanguage: savedTranslation.targetLanguage,
                        inputMode: savedTranslation.inputMode
                    )
                )
            }
        } catch {
            crash.capture(error, context: ["feature": "translate_toggle_favorite"])
            presentError((error as? AppError)?.viewError ?? .generic, action: .clear)
        }
    }

    func trackCopiedCurrentResult() {
        guard let currentResult else {
            return
        }
        analytics.track(
            .translationCopied,
            properties: translationAnalyticsProperties(
                sourceLanguage: currentResult.sourceLanguage,
                targetLanguage: currentResult.targetLanguage,
                inputMode: currentResult.inputMode
            )
        )
    }

    func trackSharedCurrentResult() {
        guard let currentResult else {
            return
        }
        analytics.track(
            .translationShared,
            properties: translationAnalyticsProperties(
                sourceLanguage: currentResult.sourceLanguage,
                targetLanguage: currentResult.targetLanguage,
                inputMode: currentResult.inputMode
            )
        )
    }

    func handleVisibleErrorAction() {
        switch errorAction {
        case .clear:
            clearTranslationError()
        case .retryTranslation:
            requestTranslation()
        case .retryVoiceCapture:
            Task { await startVoiceCapture() }
        case .openSettings:
            guard let settingsURL = URL(string: UIApplication.openSettingsURLString) else {
                clearTranslationError()
                return
            }
            UIApplication.shared.open(settingsURL)
        }
    }

    private func handleTranslationFailure(_ error: Error) {
        isTranslating = false
        pendingRequest = nil

        let mappedError = Self.mapTranslationError(error)
        if mappedError.shouldCapture {
            crash.capture(error, context: ["feature": "translate_execute"])
        }

        presentError(mappedError.viewError, action: mappedError.action)
        analytics.track(
            .translateFailed,
            properties: ["reason": mappedError.reason]
        )
    }

    private func presentError(_ error: ViewError, action: TranslateErrorAction) {
        translationError = error
        errorAction = action
    }

    private func clearTranslationError() {
        translationError = nil
        errorAction = .clear
    }

    private func translationAnalyticsProperties(
        sourceLanguage: String,
        targetLanguage: String,
        inputMode: TranslationInputMode
    ) -> [String: String] {
        [
            "input_mode": inputMode.rawValue,
            "source_language": Self.minimalLanguageIdentifier(from: sourceLanguage),
            "target_language": Self.minimalLanguageIdentifier(from: targetLanguage)
        ]
    }

    private func presentVoiceCaptureError(_ error: Error) {
        let mappedError = Self.mapVoiceCaptureError(error)
        presentError(mappedError.viewError, action: mappedError.action)
    }

    private func preferredVoiceRecognizerLocaleIdentifier() -> String? {
        if let manualSourceLanguage = sourceSelection.language {
            return preferredLocaleIdentifier(for: manualSourceLanguage.code) ?? manualSourceLanguage.code
        }

        return Locale.preferredLanguages.first
    }

    private func preferredLocaleIdentifier(for languageCode: String) -> String? {
        let normalizedCode = Self.baseLanguageCode(from: languageCode)
        if let preferredLocale = Locale.preferredLanguages.first(where: {
            Self.baseLanguageCode(from: $0) == normalizedCode
        }) {
            return preferredLocale
        }

        return nil
    }

    private static func minimalLanguageIdentifier(from identifier: String) -> String {
        let language = Locale.Language(identifier: normalizedLanguageIdentifier(from: identifier))
        if let baseLanguageCode = language.languageCode?.identifier,
           !baseLanguageCode.isEmpty {
            return baseLanguageCode.lowercased()
        }

        return language.minimalIdentifier.lowercased()
    }

    private func translationUnavailableError() -> ViewError {
        if translationLanguageSupport.isSimulatorEnvironment {
            return ViewError(
                title: "Translation requires a device",
                message: "Apple's Translation framework isn't available in the iOS Simulator. Run LinguaDaily on a physical iPhone or iPad to translate text.",
                actionTitle: "OK"
            )
        }

        return ViewError(
            title: "Translation unavailable",
            message: "We couldn't load the supported translation languages on this device yet. Please try again in a moment.",
            actionTitle: "Retry"
        )
    }

    private func unsupportedTranslationLanguageError(for languageName: String) -> ViewError {
        ViewError(
            title: "Translation unavailable",
            message: "\(languageName) isn't available for on-device translation on this device yet.",
            actionTitle: "OK"
        )
    }

    private func resolvedTranslationLanguage(for code: String) -> Locale.Language? {
        let normalizedCode = Self.normalizedLanguageIdentifier(from: code)
        let baseLanguageCode = Self.baseLanguageCode(from: normalizedCode)

        if let exactMatch = supportedTranslationLanguages.first(where: {
            Self.normalizedLanguageIdentifier(from: $0.minimalIdentifier) == normalizedCode
        }) {
            return exactMatch
        }

        let candidates = supportedTranslationLanguages.filter {
            Self.baseLanguageCode(from: $0.minimalIdentifier) == baseLanguageCode
        }

        guard !candidates.isEmpty else {
            return nil
        }

        if let preferredCandidate = preferredTranslationLanguage(from: candidates, baseLanguageCode: baseLanguageCode) {
            return preferredCandidate
        }

        if baseLanguageCode == "zh" {
            return candidates.first(where: { $0.region?.identifier.uppercased() == "CN" }) ?? candidates.first
        }

        return candidates.first
    }

    private func preferredTranslationLanguage(
        from candidates: [Locale.Language],
        baseLanguageCode: String
    ) -> Locale.Language? {
        for preferredIdentifier in Locale.preferredLanguages {
            let preferredLanguage = Locale.Language(identifier: preferredIdentifier)
            guard preferredLanguage.languageCode?.identifier.lowercased() == baseLanguageCode else {
                continue
            }

            if let region = preferredLanguage.region,
               let regionalMatch = candidates.first(where: { $0.region == region }) {
                return regionalMatch
            }
        }

        return nil
    }

    private static func normalizedLanguageIdentifier(from identifier: String) -> String {
        identifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
    }

    private static func baseLanguageCode(from identifier: String) -> String {
        let language = Locale.Language(identifier: normalizedLanguageIdentifier(from: identifier))
        if let baseLanguageCode = language.languageCode?.identifier,
           !baseLanguageCode.isEmpty {
            return baseLanguageCode.lowercased()
        }

        return normalizedLanguageIdentifier(from: identifier)
    }

    private static func mapTranslationError(_ error: Error) -> MappedTranslationError {
        if TranslationError.nothingToTranslate ~= error {
            return MappedTranslationError(
                viewError: AppError.validation("Enter a word, phrase, or sentence to translate.").viewError,
                action: .clear,
                shouldCapture: false,
                reason: "nothing_to_translate"
            )
        }

        if TranslationError.unableToIdentifyLanguage ~= error {
            return MappedTranslationError(
                viewError: AppError.validation("We couldn't detect the source language. Choose it manually or try a longer phrase.").viewError,
                action: .clear,
                shouldCapture: false,
                reason: "unable_to_identify_language"
            )
        }

        if TranslationError.unsupportedSourceLanguage ~= error
            || TranslationError.unsupportedTargetLanguage ~= error
            || TranslationError.unsupportedLanguagePairing ~= error {
            return MappedTranslationError(
                viewError: AppError.validation("That language pair isn't supported yet. Pick a different source or target language.").viewError,
                action: .clear,
                shouldCapture: false,
                reason: "unsupported_language_pair"
            )
        }

        if TranslationError.notInstalled ~= error {
            return MappedTranslationError(
                viewError: ViewError(
                    title: "Translation unavailable",
                    message: "The required language pack is not ready yet. Try again in a moment.",
                    actionTitle: "Retry"
                ),
                action: .retryTranslation,
                shouldCapture: false,
                reason: "not_installed"
            )
        }

        if TranslationError.alreadyCancelled ~= error {
            return MappedTranslationError(
                viewError: ViewError(
                    title: "Translation canceled",
                    message: "Try the translation again when you're ready.",
                    actionTitle: "Retry"
                ),
                action: .retryTranslation,
                shouldCapture: false,
                reason: "already_cancelled"
            )
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return MappedTranslationError(
            viewError: ViewError(
                title: "Translation unavailable",
                message: message.isEmpty ? "We couldn't complete that translation. Please try again." : message,
                actionTitle: "Retry"
            ),
            action: .retryTranslation,
            shouldCapture: true,
            reason: "unexpected"
        )
    }

    private static func mapVoiceCaptureError(_ error: Error) -> MappedTranslationError {
        if let voiceError = error as? VoiceTranslationError {
            switch voiceError {
            case .microphonePermissionDenied:
                return MappedTranslationError(
                    viewError: ViewError(
                        title: "Microphone access needed",
                        message: "Allow microphone access in Settings before starting voice translation.",
                        actionTitle: "Open Settings"
                    ),
                    action: .openSettings,
                    shouldCapture: false,
                    reason: "microphone_permission_denied"
                )
            case .speechRecognitionPermissionDenied:
                return MappedTranslationError(
                    viewError: ViewError(
                        title: "Speech access needed",
                        message: "Allow speech recognition in Settings before starting voice translation.",
                        actionTitle: "Open Settings"
                    ),
                    action: .openSettings,
                    shouldCapture: false,
                    reason: "speech_permission_denied"
                )
            case .recognitionUnavailable:
                return MappedTranslationError(
                    viewError: ViewError(
                        title: "Voice translation unavailable",
                        message: "Speech recognition isn't available on this device right now.",
                        actionTitle: "OK"
                    ),
                    action: .clear,
                    shouldCapture: false,
                    reason: "recognition_unavailable"
                )
            case .audioSessionUnavailable:
                return MappedTranslationError(
                    viewError: ViewError(
                        title: "Voice translation unavailable",
                        message: "We couldn't start the microphone session. Please try again.",
                        actionTitle: "Retry"
                    ),
                    action: .retryVoiceCapture,
                    shouldCapture: false,
                    reason: "audio_session_unavailable"
                )
            case .noSpeechDetected:
                return MappedTranslationError(
                    viewError: ViewError(
                        title: "No speech detected",
                        message: "Try speaking a little longer or move somewhere quieter, then try again.",
                        actionTitle: "Try Again"
                    ),
                    action: .retryVoiceCapture,
                    shouldCapture: false,
                    reason: "no_speech_detected"
                )
            }
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return MappedTranslationError(
            viewError: ViewError(
                title: "Voice translation unavailable",
                message: message.isEmpty ? "We couldn't capture your speech. Please try again." : message,
                actionTitle: "Try Again"
            ),
            action: .retryVoiceCapture,
            shouldCapture: true,
            reason: "voice_unexpected"
        )
    }
}

@MainActor
final class SavedTranslationsViewModel: ObservableObject {
    @Published private(set) var phase: AsyncPhase<[SavedTranslation]> = .idle
    @Published private(set) var bannerError: ViewError?
    @Published var query = ""
    @Published var filter: TranslationLibraryFilter = .all

    private let translationService: TranslationServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private var allTranslations: [SavedTranslation] = []

    init(
        translationService: TranslationServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.translationService = translationService
        self.analytics = analytics
        self.crash = crash
    }

    func load() async {
        phase = .loading
        bannerError = nil

        do {
            allTranslations = try await translationService.fetchSavedTranslations()
            applyFilters()
            analytics.track(
                .translationLibraryOpened,
                properties: ["count": "\(allTranslations.count)"]
            )
        } catch {
            crash.capture(error, context: ["feature": "translation_library_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func updateQuery(_ query: String) {
        self.query = query
        applyFilters()
        analytics.track(
            .translationLibrarySearched,
            properties: ["length": "\(query.count)"]
        )
    }

    func updateFilter(_ filter: TranslationLibraryFilter) {
        self.filter = filter
        applyFilters()
        analytics.track(
            .translationLibraryFilterChanged,
            properties: ["filter": filter.rawValue]
        )
    }

    func translation(id: UUID) -> SavedTranslation? {
        allTranslations.first(where: { $0.id == id })
    }

    func toggleFavorite(id: UUID) async {
        guard let translation = translation(id: id) else {
            return
        }

        do {
            let updatedTranslation = try await translationService.updateSavedTranslation(
                id: id,
                isFavorited: !translation.isFavorited
            )
            replaceTranslation(updatedTranslation)
            applyFilters()
            analytics.track(
                updatedTranslation.isFavorited ? .translationFavorited : .translationUnfavorited,
                properties: analyticsProperties(for: updatedTranslation)
            )
        } catch {
            crash.capture(error, context: ["feature": "translation_library_toggle_favorite"])
            bannerError = (error as? AppError)?.viewError ?? .generic
        }
    }

    func removeSave(id: UUID) async {
        guard let translation = translation(id: id) else {
            return
        }

        do {
            try await translationService.deleteSavedTranslation(id: id)
            allTranslations.removeAll { $0.id == id }
            applyFilters()
            analytics.track(
                .translationRemoved,
                properties: analyticsProperties(for: translation)
            )
        } catch {
            crash.capture(error, context: ["feature": "translation_library_remove_save"])
            bannerError = (error as? AppError)?.viewError ?? .generic
        }
    }

    func trackDetailOpened(id: UUID) {
        guard let translation = translation(id: id) else {
            return
        }
        analytics.track(
            .translationDetailOpened,
            properties: analyticsProperties(for: translation)
        )
    }

    func trackCopiedTranslation(id: UUID) {
        guard let translation = translation(id: id) else {
            return
        }
        analytics.track(
            .translationCopied,
            properties: analyticsProperties(for: translation)
        )
    }

    func trackSharedTranslation(id: UUID) {
        guard let translation = translation(id: id) else {
            return
        }
        analytics.track(
            .translationShared,
            properties: analyticsProperties(for: translation)
        )
    }

    func clearBannerError() {
        bannerError = nil
    }

    private func replaceTranslation(_ translation: SavedTranslation) {
        guard let index = allTranslations.firstIndex(where: { $0.id == translation.id }) else {
            return
        }
        allTranslations[index] = translation
        allTranslations.sort(by: { $0.createdAt > $1.createdAt })
    }

    private func applyFilters() {
        let filteredTranslations = Self.filterTranslations(
            allTranslations,
            filter: filter,
            query: query
        )

        if filteredTranslations.isEmpty {
            phase = .empty
        } else {
            phase = .success(filteredTranslations)
        }
    }

    private func analyticsProperties(for translation: SavedTranslation) -> [String: String] {
        [
            "input_mode": translation.inputMode.rawValue,
            "source_language": translation.sourceLanguage,
            "target_language": translation.targetLanguage
        ]
    }

    static func filterTranslations(
        _ translations: [SavedTranslation],
        filter: TranslationLibraryFilter,
        query: String
    ) -> [SavedTranslation] {
        let filteredByState = translations.filter { translation in
            switch filter {
            case .all:
                return true
            case .favorites:
                return translation.isFavorited
            }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedQuery.isEmpty else {
            return filteredByState.sorted(by: { $0.createdAt > $1.createdAt })
        }

        return filteredByState
            .filter {
                $0.sourceText.localizedCaseInsensitiveContains(trimmedQuery)
                    || $0.translatedText.localizedCaseInsensitiveContains(trimmedQuery)
            }
            .sorted(by: { $0.createdAt > $1.createdAt })
    }
}

private enum TranslateErrorAction {
    case clear
    case retryTranslation
    case retryVoiceCapture
    case openSettings
}

private struct MappedTranslationError {
    let viewError: ViewError
    let action: TranslateErrorAction
    let shouldCapture: Bool
    let reason: String
}
