import XCTest
@testable import LinguaDaily

final class SupabaseWordCatalogPersistenceServiceTests: XCTestCase {
    func testPersistIfNeededSavesDiscoveredWordWhenLemmaDiffers() async {
        let remoteStore = MockWordCatalogRemoteStore(result: .success(
            ExternalWordPersistResult(
                wordID: UUID(uuidString: "99999999-8888-7777-6666-555555555555")!,
                wasInserted: true
            )
        ))
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let service = SupabaseWordCatalogPersistenceService(
            remoteStore: remoteStore,
            analytics: analytics,
            crash: crash
        )

        let baseWord = EnrichmentFixtures.word(languageCode: "es", lemma: "hablo")
        let candidate = DiscoveredWordCandidate(
            languageCode: "es",
            lemma: "hablar",
            transliteration: nil,
            pronunciationIPA: "/aˈβlaɾ/",
            pronunciationGuidance: "Spain",
            partOfSpeech: "verb",
            definition: "to speak",
            usageNotes: "Pronunciation: Spain",
            examples: [
                ExampleSentence(id: UUID(), sentence: "Hablar es vivir.", translation: "", order: 1, source: "wiktionary")
            ],
            audio: [
                WordAudio(
                    id: UUID(),
                    accent: "Spain",
                    speed: "native",
                    url: URL(string: "https://audio.forvo.com/hablar.mp3")!,
                    durationMS: 0,
                    source: "forvo",
                    speakerLabel: "maria",
                    providerReference: "11"
                ),
                WordAudio(
                    id: UUID(),
                    accent: "spain",
                    speed: "native",
                    url: URL(fileURLWithPath: "/tmp/google.mp3"),
                    durationMS: 0,
                    source: "google-tts"
                )
            ],
            languageVariant: "Spain",
            sources: ["wiktionary", "forvo"]
        )

        await service.persistIfNeeded(candidate: candidate, baseWord: baseWord)

        XCTAssertEqual(remoteStore.requests.count, 1)
        XCTAssertEqual(remoteStore.requests.first?.lemma, "hablar")
        XCTAssertEqual(remoteStore.requests.first?.language_code, "es")
        XCTAssertEqual(remoteStore.requests.first?.audio.count, 1)
        XCTAssertEqual(remoteStore.requests.first?.audio.first?.audio_url, "https://audio.forvo.com/hablar.mp3")
        XCTAssertEqual(analytics.events.map(\.event), [.discoveredNewWord, .persistedNewWordSuccess])
        XCTAssertTrue(crash.contexts.isEmpty)
    }

    func testPersistIfNeededPreventsDuplicatePersistenceForNormalizedLemmaAndLanguageCode() async {
        let remoteStore = MockWordCatalogRemoteStore(result: .success(
            ExternalWordPersistResult(wordID: UUID(), wasInserted: false)
        ))
        let service = SupabaseWordCatalogPersistenceService(
            remoteStore: remoteStore,
            analytics: TestAnalyticsService(),
            crash: TestCrashReportingService()
        )

        let baseWord = EnrichmentFixtures.word(languageCode: "fr", lemma: " Bonjour ")
        let candidate = DiscoveredWordCandidate(
            languageCode: "fr",
            lemma: "bonjour",
            transliteration: nil,
            pronunciationIPA: nil,
            pronunciationGuidance: nil,
            partOfSpeech: nil,
            definition: "hello",
            usageNotes: nil,
            examples: [],
            audio: [],
            languageVariant: nil,
            sources: ["wiktionary"]
        )

        await service.persistIfNeeded(candidate: candidate, baseWord: baseWord)

        XCTAssertTrue(remoteStore.requests.isEmpty)
    }

    func testPersistIfNeededReportsFailureWithoutThrowing() async {
        let remoteStore = MockWordCatalogRemoteStore(result: .failure(AppError.network("Insert failed")))
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let service = SupabaseWordCatalogPersistenceService(
            remoteStore: remoteStore,
            analytics: analytics,
            crash: crash
        )

        let baseWord = EnrichmentFixtures.word(languageCode: "es", lemma: "hablo")
        let candidate = DiscoveredWordCandidate(
            languageCode: "es",
            lemma: "hablar",
            transliteration: nil,
            pronunciationIPA: nil,
            pronunciationGuidance: nil,
            partOfSpeech: "verb",
            definition: "to speak",
            usageNotes: nil,
            examples: [],
            audio: [],
            languageVariant: nil,
            sources: ["wiktionary"]
        )

        await service.persistIfNeeded(candidate: candidate, baseWord: baseWord)

        XCTAssertEqual(crash.contexts.first?["tag"], "supabase_persist_new_word_failure")
        XCTAssertEqual(analytics.events.map(\.event), [.discoveredNewWord, .persistedNewWordFailure])
    }
}

private final class MockWordCatalogRemoteStore: WordCatalogRemoteStoring {
    var result: Result<ExternalWordPersistResult, Error>
    private(set) var requests: [ExternalWordPersistRequest] = []

    init(result: Result<ExternalWordPersistResult, Error>) {
        self.result = result
    }

    func upsertWord(_ request: ExternalWordPersistRequest) async throws -> ExternalWordPersistResult {
        requests.append(request)
        return try result.get()
    }
}
