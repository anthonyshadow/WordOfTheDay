import Foundation
import Supabase

protocol WordCatalogPersisting {
    func persistIfNeeded(candidate: DiscoveredWordCandidate, baseWord: Word) async
}

protocol WordCatalogRemoteStoring {
    func upsertWord(_ request: ExternalWordPersistRequest) async throws -> ExternalWordPersistResult
}

final class SupabaseWordCatalogPersistenceService: WordCatalogPersisting {
    private let remoteStore: WordCatalogRemoteStoring
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol

    init(
        config: SupabaseConfig,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.remoteStore = SupabaseWordCatalogRemoteStore(
            client: SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
        )
        self.analytics = analytics
        self.crash = crash
    }

    init(
        remoteStore: WordCatalogRemoteStoring,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol
    ) {
        self.remoteStore = remoteStore
        self.analytics = analytics
        self.crash = crash
    }

    func persistIfNeeded(candidate: DiscoveredWordCandidate, baseWord: Word) async {
        let normalizedBaseLemma = WordNormalizer.normalizeLemma(baseWord.lemma)
        let normalizedCandidateLemma = WordNormalizer.normalizeLemma(candidate.lemma)

        guard normalizedCandidateLemma.isEmpty == false,
              normalizedCandidateLemma != normalizedBaseLemma else {
            return
        }

        let trimmedDefinition = candidate.definition.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedDefinition.isEmpty == false else {
            return
        }

        analytics.track(.discoveredNewWord, properties: [
            "base_word": baseWord.lemma,
            "candidate_word": candidate.lemma,
            "language": candidate.languageCode
        ])

        let request = ExternalWordPersistRequest(
            language_code: candidate.languageCode,
            lemma: candidate.lemma,
            transliteration: candidate.transliteration,
            pronunciation_ipa: candidate.pronunciationIPA,
            pronunciation_guidance: candidate.pronunciationGuidance,
            part_of_speech: candidate.partOfSpeech,
            cefr_level: nil,
            definition: trimmedDefinition,
            usage_notes: candidate.usageNotes,
            language_variant: candidate.languageVariant,
            enrichment_source: candidate.sources.first,
            examples: candidate.examples
                .filter { $0.sentence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false }
                .prefix(3)
                .map {
                    ExternalWordPersistExample(
                        sentence: $0.sentence,
                        translation: $0.translation,
                        source: $0.source
                    )
                },
            audio: candidate.audio
                .filter {
                    guard let scheme = $0.url.scheme?.lowercased() else {
                        return false
                    }
                    return scheme == "http" || scheme == "https"
                }
                .map {
                    ExternalWordPersistAudio(
                        accent: $0.accent,
                        speed: $0.speed,
                        audio_url: $0.url.absoluteString,
                        duration_ms: $0.durationMS > 0 ? $0.durationMS : nil,
                        source: $0.source,
                        speaker_label: $0.speakerLabel,
                        provider_reference: $0.providerReference
                    )
                }
        )

        do {
            let response = try await remoteStore.upsertWord(request)

            analytics.track(.persistedNewWordSuccess, properties: [
                "base_word": baseWord.lemma,
                "candidate_word": candidate.lemma,
                "language": candidate.languageCode,
                "inserted": response.wasInserted ? "true" : "false",
                "word_id": response.wordID.uuidString
            ])
        } catch {
            crash.capture(error, context: [
                "feature": "word_catalog_persist",
                "tag": "supabase_persist_new_word_failure",
                "base_word": baseWord.lemma,
                "candidate_word": candidate.lemma,
                "language": candidate.languageCode
            ])
            analytics.track(.persistedNewWordFailure, properties: [
                "base_word": baseWord.lemma,
                "candidate_word": candidate.lemma,
                "language": candidate.languageCode
            ])
        }
    }
}

struct ExternalWordPersistRequest: Encodable {
    let language_code: String
    let lemma: String
    let transliteration: String?
    let pronunciation_ipa: String?
    let pronunciation_guidance: String?
    let part_of_speech: String?
    let cefr_level: String?
    let definition: String
    let usage_notes: String?
    let language_variant: String?
    let enrichment_source: String?
    let examples: [ExternalWordPersistExample]
    let audio: [ExternalWordPersistAudio]
}

struct ExternalWordPersistExample: Encodable {
    let sentence: String
    let translation: String
    let source: String?
}

struct ExternalWordPersistAudio: Encodable {
    let accent: String
    let speed: String
    let audio_url: String
    let duration_ms: Int?
    let source: String?
    let speaker_label: String?
    let provider_reference: String?
}

struct ExternalWordPersistResult: Equatable {
    let wordID: UUID
    let wasInserted: Bool
}

private struct ExternalWordPersistResponse: Decodable {
    let word_id: UUID
    let was_inserted: Bool
}

private final class SupabaseWordCatalogRemoteStore: WordCatalogRemoteStoring {
    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func upsertWord(_ request: ExternalWordPersistRequest) async throws -> ExternalWordPersistResult {
        let response: ExternalWordPersistResponse = try await client
            .rpc("upsert_external_word", params: request)
            .single()
            .execute()
            .value

        return ExternalWordPersistResult(
            wordID: response.word_id,
            wasInserted: response.was_inserted
        )
    }
}
