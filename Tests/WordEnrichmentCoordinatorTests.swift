import SwiftData
import XCTest
@testable import LinguaDaily

@MainActor
final class WordEnrichmentCoordinatorTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testEnrichUsesFreshCacheWithoutCallingProviders() async throws {
        let cacheStore = try makeCacheStore()
        let cachedTrack = WordAudio(
            id: UUID(),
            accent: "parisian",
            speed: "native",
            url: URL(string: "https://example.com/forvo.mp3")!,
            durationMS: 1200,
            source: "forvo"
        )
        try cacheStore.saveWordEnrichment(
            WordEnrichmentSnapshot(
                lemma: nil,
                transliteration: nil,
                pronunciationIPA: nil,
                partOfSpeech: nil,
                definition: nil,
                supplementalDefinition: nil,
                usageNotes: nil,
                examples: [],
                audio: [cachedTrack],
                pronunciationGuidance: nil,
                languageVariant: nil,
                sources: ["forvo"],
                updatedAt: Date(timeIntervalSince1970: 1_720_000_000)
            ),
            for: EnrichmentFixtures.word().id
        )

        let wiktionary = TestWiktionaryClient()
        let forvo = TestForvoClient()
        let google = TestGoogleTTSClient()
        let coordinator = WordEnrichmentCoordinator(
            wiktionaryClient: wiktionary,
            forvoClient: forvo,
            googleTextToSpeechClient: google,
            cacheStore: cacheStore,
            persistenceService: nil,
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService(),
            now: { Date(timeIntervalSince1970: 1_720_000_100) }
        )

        let lesson = EnrichmentFixtures.lesson(word: EnrichmentFixtures.word())
        let enriched = await coordinator.enrich(lesson, preferredAccent: "parisian")

        XCTAssertEqual(enriched.word.audio.first?.source, "forvo")
        XCTAssertEqual(wiktionary.callCount, 0)
        XCTAssertEqual(forvo.callCount, 0)
        XCTAssertEqual(google.callCount, 0)
    }

    func testWiktionaryFailureStillReturnsBaseLessonData() async {
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let coordinator = WordEnrichmentCoordinator(
            wiktionaryClient: TestWiktionaryClient(result: .failure(AppError.network("No response"))),
            forvoClient: TestForvoClient(result: .success([])),
            googleTextToSpeechClient: TestGoogleTTSClient(result: .success(nil)),
            cacheStore: nil,
            persistenceService: nil,
            analytics: analytics,
            crash: crash
        )

        let lesson = EnrichmentFixtures.lesson(word: EnrichmentFixtures.word())
        let enriched = await coordinator.enrich(lesson, preferredAccent: nil)

        XCTAssertEqual(enriched.word.definition, lesson.word.definition)
        XCTAssertEqual(enriched.word.audio, lesson.word.audio)
        XCTAssertEqual(crash.contexts.first?["tag"], "wiktionary_error")
        XCTAssertEqual(analytics.events.last?.event, .enrichmentProviderFailed)
    }

    func testForvoFailureFallsBackToGoogleTTSWhenNoBaseAudio() async {
        let crash = TestCrashReportingService()
        let googleTrack = WordAudio(
            id: UUID(),
            accent: "spain",
            speed: "native",
            url: URL(fileURLWithPath: "/tmp/google-tts.mp3"),
            durationMS: 0,
            source: "google-tts"
        )
        let coordinator = WordEnrichmentCoordinator(
            wiktionaryClient: TestWiktionaryClient(result: .success(nil)),
            forvoClient: TestForvoClient(result: .failure(URLError(.timedOut))),
            googleTextToSpeechClient: TestGoogleTTSClient(result: .success(googleTrack)),
            cacheStore: nil,
            persistenceService: nil,
            analytics: TestAnalyticsService(),
            crash: crash
        )

        let word = EnrichmentFixtures.word(audio: [])
        let lesson = EnrichmentFixtures.lesson(word: word)
        let enriched = await coordinator.enrich(lesson, preferredAccent: "spain")

        XCTAssertEqual(enriched.word.audio.first?.source, "google-tts")
        XCTAssertEqual(crash.contexts.first?["tag"], "forvo_timeout")
    }

    func testAllEnrichmentFailuresStillReturnsBaseLessonWithoutThrowing() async {
        let crash = TestCrashReportingService()
        let coordinator = WordEnrichmentCoordinator(
            wiktionaryClient: TestWiktionaryClient(result: .failure(AppError.decoding("Broken"))),
            forvoClient: TestForvoClient(result: .failure(AppError.auth("Forvo rejected the API key."))),
            googleTextToSpeechClient: TestGoogleTTSClient(result: .failure(URLError(.timedOut))),
            cacheStore: nil,
            persistenceService: nil,
            analytics: TestAnalyticsService(),
            crash: crash
        )

        let lesson = EnrichmentFixtures.lesson(word: EnrichmentFixtures.word(audio: []))
        let enriched = await coordinator.enrich(lesson, preferredAccent: nil)

        XCTAssertEqual(enriched, lesson)
        XCTAssertEqual(crash.contexts.compactMap { $0["tag"] }.sorted(), [
            "forvo_401",
            "gcp_tts_timeout",
            "wiktionary_parse_error",
        ].sorted())
    }

    func testCoordinatorMergesRealisticWiktionaryPayloadWithMockedAudioProviders() async {
        MockURLProtocol.requestHandler = { request in
            let payload = """
            {
              "Spanish": [
                {
                  "word": "hablar",
                  "language": "Spanish",
                  "partOfSpeech": "verb",
                  "definitions": [
                    {
                      "definition": "to speak",
                      "examples": ["Hablar es vivir."]
                    }
                  ],
                  "pronunciations": {
                    "text": [
                      {
                        "ipa": "/aˈβlaɾ/",
                        "note": "Spain"
                      }
                    ]
                  }
                }
              ]
            }
            """

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(payload.utf8)
            )
        }

        let forvoTrack = WordAudio(
            id: UUID(),
            accent: "Spain",
            speed: "native",
            url: URL(string: "https://audio.forvo.com/hablar.mp3")!,
            durationMS: 0,
            source: "forvo"
        )

        let coordinator = WordEnrichmentCoordinator(
            wiktionaryClient: WiktionaryAPIClient(session: MockURLProtocol.makeSession()),
            forvoClient: TestForvoClient(result: .success([forvoTrack])),
            googleTextToSpeechClient: TestGoogleTTSClient(result: .success(nil)),
            cacheStore: nil,
            persistenceService: nil,
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService()
        )

        let baseWord = EnrichmentFixtures.word(
            languageCode: "es",
            lemma: "hablar",
            definition: "",
            usageNotes: "",
            pronunciationIPA: "",
            examples: [],
            audio: []
        )
        let lesson = EnrichmentFixtures.lesson(word: baseWord)

        let enriched = await coordinator.enrich(lesson, preferredAccent: "spain")

        XCTAssertEqual(enriched.word.definition, "to speak")
        XCTAssertEqual(enriched.word.pronunciationIPA, "/aˈβlaɾ/")
        XCTAssertEqual(enriched.word.examples.map(\.sentence), ["Hablar es vivir."])
        XCTAssertEqual(enriched.word.audio.first?.source, "forvo")
    }

    private func makeCacheStore() throws -> LocalCacheStore {
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self,
            CachedWordEnrichmentEntity.self
        ])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let configuration = ModelConfiguration(
            "WordEnrichmentCoordinatorTests",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return LocalCacheStore(modelContainer: container)
    }
}

private final class TestWiktionaryClient: WiktionaryAPIClientProtocol {
    var result: Result<WordEnrichmentSnapshot?, Error>
    private(set) var callCount = 0

    init(result: Result<WordEnrichmentSnapshot?, Error> = .success(nil)) {
        self.result = result
    }

    func fetchEnrichment(for lemma: String, languageCode: String) async throws -> WordEnrichmentSnapshot? {
        callCount += 1
        return try result.get()
    }
}

private final class TestForvoClient: ForvoAPIClientProtocol {
    var result: Result<[WordAudio], Error>
    private(set) var callCount = 0

    init(result: Result<[WordAudio], Error> = .success([])) {
        self.result = result
    }

    func fetchPronunciationAudio(for lemma: String, languageCode: String, preferredAccent: String?) async throws -> [WordAudio] {
        callCount += 1
        return try result.get()
    }
}

private final class TestGoogleTTSClient: GoogleTextToSpeechClientProtocol {
    var result: Result<WordAudio?, Error>
    private(set) var callCount = 0

    init(result: Result<WordAudio?, Error> = .success(nil)) {
        self.result = result
    }

    func synthesizePronunciation(for lemma: String, languageCode: String, preferredAccent: String?) async throws -> WordAudio? {
        callCount += 1
        return try result.get()
    }
}
