import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var phase: AsyncPhase<DailyLesson> = .idle
    @Published var reviewDueCount = 0
    @Published var audioError: ViewError?

    private let lessonService: DailyLessonServiceProtocol
    private let reviewService: ReviewServiceProtocol
    private let audioPlayer: AudioPlayerServiceProtocol
    private let cacheStore: LocalCacheStore
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol

    init(
        lessonService: DailyLessonServiceProtocol,
        reviewService: ReviewServiceProtocol,
        audioPlayer: AudioPlayerServiceProtocol,
        cacheStore: LocalCacheStore,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.lessonService = lessonService
        self.reviewService = reviewService
        self.audioPlayer = audioPlayer
        self.cacheStore = cacheStore
        self.analytics = analytics
        self.crash = crash
    }

    func load() async {
        phase = .loading
        do {
            let lesson = try await lessonService.fetchTodayLesson()
            try? cacheStore.saveDailyLesson(lesson)
            phase = .success(lesson)
            analytics.track(.todayLoaded, properties: ["word": lesson.word.lemma])
            analytics.track(.dailyWordOpened, properties: ["word": lesson.word.lemma])
        } catch {
            do {
                if let cached = try cacheStore.loadDailyLesson() {
                    phase = .success(cached)
                    analytics.track(.dailyWordOpened, properties: ["word": cached.word.lemma, "source": "cache"])
                }
            } catch {
                crash.capture(error, context: ["feature": "today_cache_load"])
            }

            if case .loading = phase {
                crash.capture(error, context: ["feature": "today_load"])
                phase = .failure((error as? AppError)?.viewError ?? .generic)
            }
        }

        do {
            reviewDueCount = try await reviewService.fetchReviewQueue().count
        } catch {
            reviewDueCount = 0
        }
    }

    func playPronunciation() async {
        guard case let .success(lesson) = phase else {
            return
        }
        guard let first = lesson.word.audio.first else {
            audioError = ViewError(
                title: "Audio unavailable offline",
                message: "Reconnect and try playing pronunciation again.",
                actionTitle: "Dismiss"
            )
            return
        }

        do {
            try await audioPlayer.play(url: first.url)
            analytics.track(.dailyWordPlayPronunciation, properties: ["word": lesson.word.lemma])
            analytics.track(.pronunciationPlayed, properties: ["word": lesson.word.lemma])
            audioError = nil
        } catch {
            crash.capture(error, context: ["feature": "play_pronunciation"])
            audioError = ViewError(
                title: "Audio load failed",
                message: "Please try again in a moment.",
                actionTitle: "Dismiss"
            )
        }
    }

    func clearAudioError() {
        audioError = nil
    }

    func toggleLearned() async {
        guard case var .success(lesson) = phase else {
            return
        }
        lesson.isLearned.toggle()
        do {
            try await lessonService.updateLessonState(wordID: lesson.word.id, isLearned: lesson.isLearned, isFavorited: nil, isSavedForReview: nil)
            phase = .success(lesson)
            let value = lesson.isLearned ? "true" : "false"
            analytics.track(.dailyWordMarkedLearned, properties: ["value": value])
            analytics.track(.wordMarkedLearned, properties: ["value": value])
        } catch {
            crash.capture(error, context: ["feature": "toggle_learned"])
        }
    }

    func toggleFavorite() async {
        guard case var .success(lesson) = phase else {
            return
        }
        lesson.isFavorited.toggle()
        do {
            try await lessonService.updateLessonState(wordID: lesson.word.id, isLearned: nil, isFavorited: lesson.isFavorited, isSavedForReview: nil)
            phase = .success(lesson)
            let value = lesson.isFavorited ? "true" : "false"
            analytics.track(.dailyWordFavorited, properties: ["value": value])
            analytics.track(.wordFavorited, properties: ["value": value])
        } catch {
            crash.capture(error, context: ["feature": "toggle_favorite"])
        }
    }

    func toggleSaveForReview() async {
        guard case var .success(lesson) = phase else {
            return
        }
        lesson.isSavedForReview.toggle()
        do {
            try await lessonService.updateLessonState(wordID: lesson.word.id, isLearned: nil, isFavorited: nil, isSavedForReview: lesson.isSavedForReview)
            phase = .success(lesson)
            analytics.track(.dailyWordSavedForReview, properties: ["value": lesson.isSavedForReview ? "true" : "false"])
        } catch {
            crash.capture(error, context: ["feature": "toggle_saved"])
        }
    }
}
