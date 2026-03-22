import SwiftData
import XCTest
@testable import LinguaDaily

@MainActor
final class LocalCacheStoreEnrichmentTests: XCTestCase {
    func testSaveAndLoadEnrichedLessonRoundTripsThroughSwiftData() throws {
        let (cacheStore, _) = try makeCacheStore()
        let enrichedWord = Word(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            languageCode: "fr",
            lemma: "bonjour",
            transliteration: nil,
            pronunciationIPA: "/bɔ̃.ʒuʁ/",
            partOfSpeech: "interjection",
            cefrLevel: "A1",
            frequencyRank: 1,
            definition: "Hello",
            usageNotes: "Pronunciation: Parisian",
            examples: [
                ExampleSentence(id: UUID(), sentence: "Bonjour tout le monde.", translation: "", order: 1, source: "wiktionary")
            ],
            audio: [
                WordAudio(
                    id: UUID(),
                    accent: "parisian",
                    speed: "native",
                    url: URL(string: "https://audio.forvo.com/bonjour.mp3")!,
                    durationMS: 0,
                    source: "forvo"
                )
            ],
            pronunciationGuidance: "Parisian",
            enrichmentSources: ["wiktionary", "forvo"],
            enrichmentUpdatedAt: Date(timeIntervalSince1970: 1_720_000_000)
        )
        let lesson = EnrichmentFixtures.lesson(word: enrichedWord)

        try cacheStore.saveDailyLesson(lesson, for: Date(timeIntervalSince1970: 1_720_000_000))

        let loaded = try cacheStore.loadDailyLesson(for: Date(timeIntervalSince1970: 1_720_000_000))

        XCTAssertEqual(loaded?.word.audio.first?.source, "forvo")
        XCTAssertEqual(loaded?.word.examples.first?.source, "wiktionary")
        XCTAssertEqual(loaded?.word.enrichmentSources, ["wiktionary", "forvo"])
    }

    func testSaveAndLoadWordEnrichmentOffline() throws {
        let (cacheStore, _) = try makeCacheStore()
        let wordID = UUID(uuidString: "11111111-2222-3333-4444-555555555555")!
        let snapshot = WordEnrichmentSnapshot(
            lemma: "bonjour",
            transliteration: nil,
            pronunciationIPA: "/bɔ̃.ʒuʁ/",
            partOfSpeech: "interjection",
            definition: "hello",
            supplementalDefinition: nil,
            usageNotes: "Pronunciation: Parisian",
            examples: [
                ExampleSentence(id: UUID(), sentence: "Bonjour tout le monde.", translation: "", order: 1, source: "wiktionary")
            ],
            audio: [],
            pronunciationGuidance: "Parisian",
            languageVariant: nil,
            sources: ["wiktionary"],
            updatedAt: Date(timeIntervalSince1970: 1_720_000_000)
        )

        try cacheStore.saveWordEnrichment(snapshot, for: wordID)
        let loaded = try cacheStore.loadWordEnrichment(for: wordID)

        XCTAssertEqual(loaded?.payload.definition, "hello")
        XCTAssertEqual(loaded?.payload.examples.first?.source, "wiktionary")
    }

    func testRemoveExpiredWordEnrichmentsRespectsExpiration() throws {
        let (cacheStore, container) = try makeCacheStore()
        let modelContext = container.mainContext
        let staleWordID = UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!
        let freshWordID = UUID(uuidString: "99999999-8888-7777-6666-555555555555")!

        try cacheStore.saveWordEnrichment(.empty(updatedAt: Date(timeIntervalSince1970: 1_720_000_000)), for: staleWordID)
        try cacheStore.saveWordEnrichment(.empty(updatedAt: Date(timeIntervalSince1970: 1_720_000_100)), for: freshWordID)

        let descriptor = FetchDescriptor<CachedWordEnrichmentEntity>()
        let entities = try modelContext.fetch(descriptor)
        entities.first(where: { $0.wordID == staleWordID })?.updatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        entities.first(where: { $0.wordID == freshWordID })?.updatedAt = Date(timeIntervalSince1970: 1_720_000_000)
        try modelContext.save()

        try cacheStore.removeExpiredWordEnrichments(olderThan: Date(timeIntervalSince1970: 1_710_000_000))

        XCTAssertNil(try cacheStore.loadWordEnrichment(for: staleWordID))
        XCTAssertNotNil(try cacheStore.loadWordEnrichment(for: freshWordID))
    }

    private func makeCacheStore() throws -> (LocalCacheStore, ModelContainer) {
        let schema = Schema([
            CachedDailyLessonEntity.self,
            CachedWordMetadataEntity.self,
            CachedWordEnrichmentEntity.self
        ])
        let storeURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("sqlite")
        let configuration = ModelConfiguration(
            "LocalCacheStoreEnrichmentTests",
            schema: schema,
            url: storeURL,
            cloudKitDatabase: .none
        )
        let container = try ModelContainer(for: schema, configurations: [configuration])
        return (LocalCacheStore(modelContainer: container), container)
    }
}
