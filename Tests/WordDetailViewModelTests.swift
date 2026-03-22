import XCTest
@testable import LinguaDaily

@MainActor
final class WordDetailViewModelTests: XCTestCase {
    func testLoadFetchesProgressStateRelatedWordsAndTracksOpen() async {
        let lessonService = TestWordDetailLessonService()
        let progressService = TestProgressService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let word = makeWord(languageCode: "it", lemma: "ciao")
        let relatedWord = makeWord(languageCode: "it", lemma: "arrivederci")
        lessonService.progressStates[word.id] = WordProgressState(
            status: .reviewDue,
            isLearned: true,
            isFavorited: true,
            isSavedForReview: true
        )
        lessonService.relatedWords = [relatedWord]
        let viewModel = WordDetailViewModel(
            word: word,
            lessonService: lessonService,
            progressService: progressService,
            audioPlayer: TestWordDetailAudioPlayerService(),
            analytics: analytics,
            crash: crash
        )

        await viewModel.load()

        XCTAssertEqual(viewModel.progressState.status, .reviewDue)
        XCTAssertTrue(viewModel.progressState.isFavorited)
        XCTAssertEqual(viewModel.relatedWords, [relatedWord])
        XCTAssertEqual(analytics.events.map(\.event), [.wordDetailOpened])
        XCTAssertTrue(crash.contexts.isEmpty)
    }

    func testToggleFavoriteUpdatesServiceAndRefreshesProgressState() async {
        let lessonService = TestWordDetailLessonService()
        let word = makeWord(languageCode: "fr", lemma: "bonjour")
        lessonService.progressStates[word.id] = .empty
        let viewModel = WordDetailViewModel(
            word: word,
            lessonService: lessonService,
            progressService: TestProgressService(),
            audioPlayer: TestWordDetailAudioPlayerService(),
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService()
        )

        await viewModel.load()
        await viewModel.toggleFavorite()

        XCTAssertEqual(lessonService.updateCalls.count, 1)
        XCTAssertEqual(lessonService.updateCalls.first?.wordID, word.id)
        XCTAssertEqual(lessonService.updateCalls.first?.isFavorited, true)
        XCTAssertTrue(viewModel.progressState.isFavorited)
    }

    func testPlayPronunciationUsesPreferredAccentTrack() async {
        let lessonService = TestWordDetailLessonService()
        let progressService = TestProgressService()
        progressService.profileResult = .success(
            makeProfile(languageCode: "ja", preferredAccent: "tokyo")
        )
        let audioPlayer = TestWordDetailAudioPlayerService()
        let word = makeWord(
            languageCode: "ja",
            lemma: "konnichiwa",
            audio: [
                WordAudio(
                    id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                    accent: "standard",
                    speed: "native",
                    url: URL(string: "https://example.com/ja-standard.mp3")!,
                    durationMS: 1200
                ),
                WordAudio(
                    id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
                    accent: "tokyo",
                    speed: "native",
                    url: URL(string: "https://example.com/ja-tokyo.mp3")!,
                    durationMS: 1200
                )
            ]
        )
        let viewModel = WordDetailViewModel(
            word: word,
            lessonService: lessonService,
            progressService: progressService,
            audioPlayer: audioPlayer,
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService()
        )

        await viewModel.load()
        await viewModel.playPronunciation()

        XCTAssertEqual(audioPlayer.playedURLs, [URL(string: "https://example.com/ja-tokyo.mp3")!])
        XCTAssertTrue(audioPlayer.spokenText.isEmpty)
    }

    func testPlayPronunciationFallsBackToSpeechWhenRemoteFails() async {
        let audioPlayer = TestWordDetailAudioPlayerService()
        let word = makeWord(languageCode: "ja", lemma: "konnichiwa")
        audioPlayer.playError = AppError.network("Missing audio")
        let viewModel = WordDetailViewModel(
            word: word,
            lessonService: TestWordDetailLessonService(),
            progressService: TestProgressService(),
            audioPlayer: audioPlayer,
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService()
        )

        await viewModel.playPronunciation(track: word.audio.first)

        XCTAssertEqual(audioPlayer.playedURLs, [word.audio[0].url])
        XCTAssertEqual(audioPlayer.spokenText, ["konnichiwa"])
        XCTAssertEqual(audioPlayer.spokenLanguageCodes, ["ja"])
        XCTAssertNil(viewModel.audioError)
    }

    func testRelatedWordOpenedTracksAnalytics() {
        let analytics = TestAnalyticsService()
        let word = makeWord(languageCode: "de", lemma: "hallo")
        let relatedWord = makeWord(languageCode: "de", lemma: "tschuss")
        let viewModel = WordDetailViewModel(
            word: word,
            lessonService: TestWordDetailLessonService(),
            progressService: TestProgressService(),
            audioPlayer: TestWordDetailAudioPlayerService(),
            analytics: analytics,
            crash: TestCrashReportingService()
        )

        viewModel.relatedWordOpened(relatedWord)

        XCTAssertEqual(analytics.events.map(\.event), [.relatedWordOpened])
        XCTAssertEqual(analytics.events.first?.properties["source_word"], "hallo")
        XCTAssertEqual(analytics.events.first?.properties["related_word"], "tschuss")
    }

    private func makeWord(
        languageCode: String,
        lemma: String,
        audio: [WordAudio]? = nil
    ) -> Word {
        Word(
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
        )
    }

    private func makeProfile(languageCode: String, preferredAccent: String?) -> UserProfile {
        UserProfile(
            id: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
            email: "user@example.com",
            displayName: "Taylor Example",
            activeLanguage: Language(
                id: UUID(uuidString: "44444444-3333-2222-1111-000000000000")!,
                code: languageCode,
                name: languageCode.uppercased(),
                nativeName: languageCode.uppercased(),
                isActive: true
            ),
            learningGoal: .travel,
            level: .beginner,
            preferredAccent: preferredAccent,
            dailyLearningMode: .balanced,
            appearancePreference: .system,
            reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
            timezoneIdentifier: "UTC",
            currentStreakDays: 5,
            bestStreakDays: 8,
            joinedAt: Date(timeIntervalSince1970: 1_690_000_000)
        )
    }
}

private final class TestWordDetailLessonService: DailyLessonServiceProtocol {
    var progressStates: [UUID: WordProgressState] = [:]
    var relatedWords: [Word] = []
    private(set) var updateCalls: [(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?)] = []

    func fetchTodayLesson() async throws -> DailyLesson {
        SampleData.todayLesson
    }

    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws {
        updateCalls.append((wordID, isLearned, isFavorited, isSavedForReview))
        let current = progressStates[wordID] ?? .empty
        let nextLearned = isLearned ?? current.isLearned
        let nextFavorited = isFavorited ?? current.isFavorited
        let nextSaved = isSavedForReview ?? current.isSavedForReview
        let nextStatus: WordStatus
        if nextSaved {
            nextStatus = .reviewDue
        } else if nextLearned {
            nextStatus = current.status == .mastered ? .mastered : .learned
        } else {
            nextStatus = .new
        }
        progressStates[wordID] = WordProgressState(
            status: nextStatus,
            isLearned: nextLearned,
            isFavorited: nextFavorited,
            isSavedForReview: nextSaved
        )
    }

    func fetchWordDetail(wordID: UUID) async throws -> Word {
        SampleData.words.first ?? SampleData.todayLesson.word
    }

    func fetchWordProgressState(wordID: UUID) async throws -> WordProgressState {
        progressStates[wordID] ?? .empty
    }

    func fetchRelatedWords(wordID: UUID, limit: Int) async throws -> [Word] {
        Array(relatedWords.prefix(limit))
    }
}

private final class TestWordDetailAudioPlayerService: AudioPlayerServiceProtocol {
    var playError: Error?
    var speakError: Error?
    private(set) var playedURLs: [URL] = []
    private(set) var spokenText: [String] = []
    private(set) var spokenLanguageCodes: [String] = []

    func play(url: URL) async throws {
        playedURLs.append(url)
        if let playError {
            throw playError
        }
    }

    func speak(text: String, languageCode: String) async throws {
        spokenText.append(text)
        spokenLanguageCodes.append(languageCode)
        if let speakError {
            throw speakError
        }
    }
}
