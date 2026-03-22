import Foundation

@MainActor
final class WordDetailViewModel: ObservableObject {
    let word: Word

    @Published private(set) var progressState: WordProgressState = .empty
    @Published private(set) var relatedWords: [Word] = []
    @Published private(set) var isLoadingState = false
    @Published private(set) var isUpdating = false
    @Published var actionError: ViewError?
    @Published var audioError: ViewError?

    private let lessonService: DailyLessonServiceProtocol
    private let progressService: ProgressServiceProtocol
    private let audioPlayer: AudioPlayerServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private var hasTrackedOpen = false
    private var preferredAccent: String?

    init(
        word: Word,
        lessonService: DailyLessonServiceProtocol,
        progressService: ProgressServiceProtocol,
        audioPlayer: AudioPlayerServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.word = word
        self.lessonService = lessonService
        self.progressService = progressService
        self.audioPlayer = audioPlayer
        self.analytics = analytics
        self.crash = crash
    }

    func load() async {
        if !hasTrackedOpen {
            analytics.track(.wordDetailOpened, properties: [
                "word": word.lemma,
                "language": word.languageCode
            ])
            hasTrackedOpen = true
        }

        isLoadingState = true
        defer { isLoadingState = false }

        do {
            progressState = try await lessonService.fetchWordProgressState(wordID: word.id)
        } catch {
            crash.capture(error, context: ["feature": "word_detail_load"])
            actionError = (error as? AppError)?.viewError ?? .generic
        }

        do {
            relatedWords = try await lessonService.fetchRelatedWords(wordID: word.id, limit: 3)
        } catch {
            crash.capture(error, context: ["feature": "word_detail_related_words"])
        }

        do {
            preferredAccent = try await progressService.fetchProfile().preferredAccent
        } catch {
            preferredAccent = nil
        }
    }

    func playPronunciation(track: WordAudio? = nil) async {
        let selectedTrack = track ?? preferredTrack(from: word.audio)

        if let selectedTrack {
            do {
                try await audioPlayer.play(url: selectedTrack.url)
                analytics.track(.pronunciationPlayed, properties: [
                    "word": word.lemma,
                    "source": "remote",
                    "speed": selectedTrack.speed
                ])
                audioError = nil
                return
            } catch {
                crash.capture(error, context: ["feature": "word_detail_play_pronunciation_remote"])
            }
        }

        do {
            try await audioPlayer.speak(text: word.lemma, languageCode: word.languageCode)
            analytics.track(.pronunciationPlayed, properties: [
                "word": word.lemma,
                "source": "tts"
            ])
            audioError = nil
        } catch {
            crash.capture(error, context: ["feature": "word_detail_play_pronunciation_tts"])
            audioError = ViewError(
                title: "Audio load failed",
                message: "Please try again in a moment.",
                actionTitle: "Dismiss"
            )
        }
    }

    func toggleLearned() async {
        let nextValue = !progressState.isLearned
        await updateProgress(
            isLearned: nextValue,
            isFavorited: nil,
            isSavedForReview: nil,
            analyticsEvent: .wordMarkedLearned,
            analyticsValue: nextValue ? "true" : "false",
            crashFeature: "word_detail_toggle_learned"
        )
    }

    func toggleFavorite() async {
        let nextValue = !progressState.isFavorited
        await updateProgress(
            isLearned: nil,
            isFavorited: nextValue,
            isSavedForReview: nil,
            analyticsEvent: .wordFavorited,
            analyticsValue: nextValue ? "true" : "false",
            crashFeature: "word_detail_toggle_favorite"
        )
    }

    func toggleSaveForReview() async {
        let nextValue = !progressState.isSavedForReview
        await updateProgress(
            isLearned: nil,
            isFavorited: nil,
            isSavedForReview: nextValue,
            analyticsEvent: .dailyWordSavedForReview,
            analyticsValue: nextValue ? "true" : "false",
            crashFeature: "word_detail_toggle_saved"
        )
    }

    func clearActionError() {
        actionError = nil
    }

    func clearAudioError() {
        audioError = nil
    }

    func relatedWordOpened(_ relatedWord: Word) {
        analytics.track(.relatedWordOpened, properties: [
            "source_word": word.lemma,
            "related_word": relatedWord.lemma
        ])
    }

    private func updateProgress(
        isLearned: Bool?,
        isFavorited: Bool?,
        isSavedForReview: Bool?,
        analyticsEvent: AnalyticsEvent,
        analyticsValue: String,
        crashFeature: String
    ) async {
        isUpdating = true
        defer { isUpdating = false }

        do {
            try await lessonService.updateLessonState(
                wordID: word.id,
                isLearned: isLearned,
                isFavorited: isFavorited,
                isSavedForReview: isSavedForReview
            )
            progressState = try await lessonService.fetchWordProgressState(wordID: word.id)
            analytics.track(analyticsEvent, properties: [
                "value": analyticsValue,
                "source": "detail"
            ])
            actionError = nil
        } catch {
            crash.capture(error, context: ["feature": crashFeature])
            actionError = (error as? AppError)?.viewError ?? .generic
        }
    }

    private func preferredTrack(from audio: [WordAudio]) -> WordAudio? {
        guard !audio.isEmpty else {
            return nil
        }

        if let preferredAccent,
           let matchingTrack = audio.first(where: {
               $0.accent.caseInsensitiveCompare(preferredAccent) == .orderedSame
           }) {
            return matchingTrack
        }

        return audio.first
    }
}
