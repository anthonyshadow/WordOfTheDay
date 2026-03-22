import Foundation
import Combine

@MainActor
final class TodayViewModel: ObservableObject {
    @Published var phase: AsyncPhase<DailyLesson> = .idle
    @Published var reviewDueCount = 0
    @Published var currentStreakDays = 0
    @Published var audioError: ViewError?

    private let lessonService: DailyLessonServiceProtocol
    private let reviewService: ReviewServiceProtocol
    private let progressService: ProgressServiceProtocol
    private let audioPlayer: AudioPlayerServiceProtocol
    private let cacheStore: DailyLessonCaching
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private var preferredAccent: String?

    init(
        lessonService: DailyLessonServiceProtocol,
        reviewService: ReviewServiceProtocol,
        progressService: ProgressServiceProtocol,
        audioPlayer: AudioPlayerServiceProtocol,
        cacheStore: DailyLessonCaching,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.lessonService = lessonService
        self.reviewService = reviewService
        self.progressService = progressService
        self.audioPlayer = audioPlayer
        self.cacheStore = cacheStore
        self.analytics = analytics
        self.crash = crash
    }

    func load() async {
        phase = .loading
        do {
            let lesson = try await lessonService.fetchTodayLesson()
            try? cacheStore.saveDailyLesson(lesson, for: .now)
            phase = .success(lesson)
            analytics.track(.todayLoaded, properties: ["word": lesson.word.lemma])
            analytics.track(.dailyWordOpened, properties: ["word": lesson.word.lemma])
        } catch {
            do {
                if let cached = try cacheStore.loadDailyLesson(for: .now) {
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
            let profile = try await progressService.fetchProfile()
            currentStreakDays = profile.currentStreakDays
            preferredAccent = profile.preferredAccent
        } catch {
            currentStreakDays = 0
            preferredAccent = nil
            crash.capture(error, context: ["feature": "today_profile_load"])
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

        if let selectedTrack = preferredTrack(from: lesson.word.audio) {
            do {
                try await audioPlayer.play(url: selectedTrack.url)
                analytics.track(.dailyWordPlayPronunciation, properties: ["word": lesson.word.lemma, "source": "remote"])
                analytics.track(.pronunciationPlayed, properties: ["word": lesson.word.lemma, "source": "remote"])
                audioError = nil
                return
            } catch {
                crash.capture(error, context: ["feature": "play_pronunciation_remote"])
            }
        }

        do {
            try await audioPlayer.speak(text: lesson.word.lemma, languageCode: lesson.word.languageCode)
            analytics.track(.dailyWordPlayPronunciation, properties: ["word": lesson.word.lemma, "source": "tts"])
            analytics.track(.pronunciationPlayed, properties: ["word": lesson.word.lemma, "source": "tts"])
            audioError = nil
        } catch {
            crash.capture(error, context: ["feature": "play_pronunciation_tts"])
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
            reviewDueCount = (try? await reviewService.fetchReviewQueue().count) ?? reviewDueCount
            analytics.track(.dailyWordSavedForReview, properties: ["value": lesson.isSavedForReview ? "true" : "false"])
        } catch {
            crash.capture(error, context: ["feature": "toggle_saved"])
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
