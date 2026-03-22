import XCTest
import SwiftData
@testable import LinguaDaily

@MainActor
final class TodayViewModelTests: XCTestCase {
    func testPlayPronunciationFallsBackToSpeechWhenRemoteAudioFails() async throws {
        let lessonService = TestDailyLessonService()
        let reviewService = TestReviewService()
        let audioPlayer = TestAudioPlayerService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let cacheStore = try makeCacheStore()

        let lesson = makeLesson(languageCode: "it", lemma: "ciao")
        lessonService.lessonResult = .success(lesson)
        audioPlayer.playError = AppError.network("Remote audio unavailable.")
        let viewModel = TodayViewModel(
            lessonService: lessonService,
            reviewService: reviewService,
            audioPlayer: audioPlayer,
            cacheStore: cacheStore,
            analytics: analytics,
            crash: crash
        )

        viewModel.phase = .success(lesson)
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
            audioPlayer: audioPlayer,
            cacheStore: try makeCacheStore(),
            analytics: analytics,
            crash: crash
        )
        let lesson = makeLesson(languageCode: "ja", lemma: "konnichiwa")
        viewModel.phase = .success(lesson)
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

    private func makeLesson(languageCode: String, lemma: String) -> DailyLesson {
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
                audio: [
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

    private func makeCacheStore() throws -> LocalCacheStore {
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self
        ])
        let configuration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return LocalCacheStore(modelContext: container.mainContext)
    }
}

@MainActor
private final class TestDailyLessonService: DailyLessonServiceProtocol {
    var lessonResult: Result<DailyLesson, Error> = .success(SampleData.todayLesson)
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
