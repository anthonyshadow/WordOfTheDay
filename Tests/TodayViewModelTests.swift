import XCTest
@testable import LinguaDaily

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testLoadUsesProfileForStreakAndPreferredAccentPlayback() async throws {
        let lessonService = TestDailyLessonService()
        let reviewService = TestReviewService()
        let progressService = TestProgressService()
        let audioPlayer = TestAudioPlayerService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let cacheStore = TestDailyLessonCacheStore()

        let lesson = makeLesson(
            languageCode: "it",
            lemma: "ciao",
            audio: [
                WordAudio(
                    id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                    accent: "standard",
                    speed: "native",
                    url: URL(string: "https://example.com/it-standard.mp3")!,
                    durationMS: 1200
                ),
                WordAudio(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                    accent: "rome",
                    speed: "native",
                    url: URL(string: "https://example.com/it-rome.mp3")!,
                    durationMS: 1200
                )
            ]
        )
        lessonService.lessonResult = .success(lesson)
        reviewService.queue = [TestData.reviewCard()]
        progressService.profileResult = .success(
            makeProfile(
                email: "italian@example.com",
                language: Language(
                    id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
                    code: "it",
                    name: "Italian",
                    nativeName: "Italiano",
                    isActive: true
                ),
                preferredAccent: "rome",
                currentStreakDays: 7,
                bestStreakDays: 11
            )
        )
        let viewModel = TodayViewModel(
            lessonService: lessonService,
            reviewService: reviewService,
            progressService: progressService,
            audioPlayer: audioPlayer,
            cacheStore: cacheStore,
            analytics: analytics,
            crash: crash
        )

        await viewModel.load()
        await viewModel.playPronunciation()

        XCTAssertEqual(viewModel.currentStreakDays, 7)
        XCTAssertEqual(viewModel.reviewDueCount, 1)
        XCTAssertEqual(audioPlayer.playedURLs, [URL(string: "https://example.com/it-rome.mp3")!])
        XCTAssertEqual(cacheStore.savedLessons.map(\.languageName), ["IT"])
        XCTAssertEqual(
            analytics.events.prefix(2).map(\.event),
            [.todayLoaded, .dailyWordOpened]
        )
        XCTAssertTrue(crash.contexts.isEmpty)
    }

    func testPlayPronunciationFallsBackToSpeechWhenRemoteAudioFails() async throws {
        let lessonService = TestDailyLessonService()
        let reviewService = TestReviewService()
        let progressService = TestProgressService()
        let audioPlayer = TestAudioPlayerService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let cacheStore = TestDailyLessonCacheStore()

        let lesson = makeLesson(languageCode: "it", lemma: "ciao")
        lessonService.lessonResult = .success(lesson)
        audioPlayer.playError = AppError.network("Remote audio unavailable.")
        let viewModel = TodayViewModel(
            lessonService: lessonService,
            reviewService: reviewService,
            progressService: progressService,
            audioPlayer: audioPlayer,
            cacheStore: cacheStore,
            analytics: analytics,
            crash: crash
        )

        viewModel.phase = AsyncPhase.success(lesson)
        await viewModel.playPronunciation()

        XCTAssertEqual(audioPlayer.playedURLs, [lesson.word.audio[0].url])
        XCTAssertEqual(audioPlayer.spokenUtterances.count, 1)
        XCTAssertEqual(audioPlayer.spokenUtterances.first?.text, "ciao")
        XCTAssertEqual(audioPlayer.spokenUtterances.first?.languageCode, "it")
        XCTAssertEqual(crash.contexts, [["feature": "play_pronunciation_remote"]])
        XCTAssertNil(viewModel.audioError)
        XCTAssertEqual(
            analytics.events.suffix(2).map(\.event),
            [.dailyWordPlayPronunciation, .pronunciationPlayed]
        )
        XCTAssertEqual(
            analytics.events.suffix(2).map { $0.properties["source"] },
            ["tts", "tts"]
        )
    }

    func testPlayPronunciationShowsErrorWhenRemoteAndSpeechFail() async throws {
        let audioPlayer = TestAudioPlayerService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let viewModel = TodayViewModel(
            lessonService: TestDailyLessonService(),
            reviewService: TestReviewService(),
            progressService: TestProgressService(),
            audioPlayer: audioPlayer,
            cacheStore: TestDailyLessonCacheStore(),
            analytics: analytics,
            crash: crash
        )
        let lesson = makeLesson(languageCode: "ja", lemma: "konnichiwa")
        viewModel.phase = AsyncPhase.success(lesson)
        audioPlayer.playError = AppError.network("Remote audio unavailable.")
        audioPlayer.speakError = AppError.network("Speech unavailable.")

        await viewModel.playPronunciation()

        XCTAssertEqual(audioPlayer.playedURLs, [lesson.word.audio[0].url])
        XCTAssertEqual(audioPlayer.spokenUtterances.count, 1)
        XCTAssertEqual(audioPlayer.spokenUtterances.first?.text, "konnichiwa")
        XCTAssertEqual(audioPlayer.spokenUtterances.first?.languageCode, "ja")
        XCTAssertEqual(crash.contexts, [
            ["feature": "play_pronunciation_remote"],
            ["feature": "play_pronunciation_tts"]
        ])
        XCTAssertEqual(viewModel.audioError?.title, "Audio load failed")
        XCTAssertTrue(analytics.events.isEmpty)
    }

    private func makeLesson(
        languageCode: String,
        lemma: String,
        audio: [WordAudio]? = nil
    ) -> DailyLesson {
        DailyLesson(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            assignmentDate: Date(timeIntervalSince1970: 1_710_000_000),
            dayNumber: 3,
            languageName: languageCode.uppercased(),
            word: Word(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                languageCode: languageCode,
                lemma: lemma,
                transliteration: nil,
                pronunciationIPA: "/demo/",
                partOfSpeech: "interjection",
                cefrLevel: "A1",
                frequencyRank: 1,
                definition: "Hello",
                usageNotes: "Greeting",
                examples: [
                    ExampleSentence(
                        id: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
                        sentence: "\(lemma)!",
                        translation: "Hello!",
                        order: 1
                    )
                ],
                audio: audio ?? [
                    WordAudio(
                        id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                        accent: "standard",
                        speed: "native",
                        url: URL(string: "https://example.com/\(languageCode).mp3")!,
                        durationMS: 1200
                    )
                ]
            ),
            isLearned: false,
            isFavorited: false,
            isSavedForReview: false
        )
    }

    private func makeProfile(
        email: String,
        language: Language?,
        preferredAccent: String?,
        currentStreakDays: Int,
        bestStreakDays: Int
    ) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: "12121212-3434-5656-7878-909090909090")!,
            email: email,
            displayName: "Taylor Example",
            activeLanguage: language,
            learningGoal: .travel,
            level: .beginner,
            preferredAccent: preferredAccent,
            dailyLearningMode: .balanced,
            appearancePreference: .system,
            reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "America/Toronto",
            currentStreakDays: currentStreakDays,
            bestStreakDays: bestStreakDays,
            joinedAt: Date(timeIntervalSince1970: 1_690_000_000)
        )
    }
}

@MainActor
private final class TestDailyLessonService: DailyLessonServiceProtocol {
    var lessonResult: Result<DailyLesson, Error> = .success(SampleData.todayLesson)
    var relatedWordsResult: [Word] = []
    private(set) var updates: [(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?)] = []

    func fetchTodayLesson() async throws -> DailyLesson {
        try lessonResult.get()
    }

    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws {
        updates.append((wordID, isLearned, isFavorited, isSavedForReview))
    }

    func fetchWordDetail(wordID: UUID) async throws -> Word {
        SampleData.words[0]
    }

    func fetchWordProgressState(wordID: UUID) async throws -> WordProgressState {
        .empty
    }

    func fetchRelatedWords(wordID: UUID, limit: Int) async throws -> [Word] {
        Array(relatedWordsResult.prefix(limit))
    }
}

@MainActor
private final class TestDailyLessonCacheStore: DailyLessonCaching {
    private(set) var savedLessons: [DailyLesson] = []
    var cachedLesson: DailyLesson?

    func saveDailyLesson(_ lesson: DailyLesson, for date: Date) throws {
        savedLessons.append(lesson)
        cachedLesson = lesson
    }

    func loadDailyLesson(for date: Date) throws -> DailyLesson? {
        cachedLesson
    }
}

private final class TestAudioPlayerService: AudioPlayerServiceProtocol {
    var playError: Error?
    var speakError: Error?
    private(set) var playedURLs: [URL] = []
    private(set) var spokenUtterances: [(text: String, languageCode: String)] = []

    func play(url: URL) async throws {
        playedURLs.append(url)
        if let playError {
            throw playError
        }
    }

    func speak(text: String, languageCode: String) async throws {
        spokenUtterances.append((text, languageCode))
        if let speakError {
            throw speakError
        }
    }
}
