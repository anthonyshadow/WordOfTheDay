import Foundation

struct WordEnrichmentSnapshot: Codable, Equatable, Sendable {
    let lemma: String?
    let transliteration: String?
    let pronunciationIPA: String?
    let partOfSpeech: String?
    let definition: String?
    let supplementalDefinition: String?
    let usageNotes: String?
    let examples: [ExampleSentence]
    let audio: [WordAudio]
    let pronunciationGuidance: String?
    let languageVariant: String?
    let sources: [String]
    let updatedAt: Date

    var hasMeaningfulContent: Bool {
        let hasText = [
            lemma,
            transliteration,
            pronunciationIPA,
            partOfSpeech,
            definition,
            supplementalDefinition,
            usageNotes,
            pronunciationGuidance,
            languageVariant
        ]
        .compactMap(Self.trimmed)
        .isEmpty == false

        return hasText || examples.isEmpty == false || audio.isEmpty == false || sources.isEmpty == false
    }

    static func empty(updatedAt: Date) -> WordEnrichmentSnapshot {
        WordEnrichmentSnapshot(
            lemma: nil,
            transliteration: nil,
            pronunciationIPA: nil,
            partOfSpeech: nil,
            definition: nil,
            supplementalDefinition: nil,
            usageNotes: nil,
            examples: [],
            audio: [],
            pronunciationGuidance: nil,
            languageVariant: nil,
            sources: [],
            updatedAt: updatedAt
        )
    }

    func merged(with other: WordEnrichmentSnapshot) -> WordEnrichmentSnapshot {
        WordEnrichmentSnapshot(
            lemma: Self.firstNonEmpty(other.lemma, lemma),
            transliteration: Self.firstNonEmpty(other.transliteration, transliteration),
            pronunciationIPA: Self.firstNonEmpty(other.pronunciationIPA, pronunciationIPA),
            partOfSpeech: Self.firstNonEmpty(other.partOfSpeech, partOfSpeech),
            definition: Self.firstNonEmpty(other.definition, definition),
            supplementalDefinition: Self.firstNonEmpty(other.supplementalDefinition, supplementalDefinition),
            usageNotes: Self.mergeParagraphs(other.usageNotes, usageNotes),
            examples: Self.mergedExamples(primary: other.examples, secondary: examples),
            audio: Self.mergedAudio(primary: other.audio, secondary: audio),
            pronunciationGuidance: Self.firstNonEmpty(other.pronunciationGuidance, pronunciationGuidance),
            languageVariant: Self.firstNonEmpty(other.languageVariant, languageVariant),
            sources: Self.uniqueStrings(other.sources + sources),
            updatedAt: max(updatedAt, other.updatedAt)
        )
    }

    private static func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedValue.isEmpty ? nil : trimmedValue
    }

    private static func firstNonEmpty(_ lhs: String?, _ rhs: String?) -> String? {
        trimmed(lhs) ?? trimmed(rhs)
    }

    private static func mergeParagraphs(_ lhs: String?, _ rhs: String?) -> String? {
        let pieces = [lhs, rhs]
            .compactMap(trimmed)
            .reduce(into: [String]()) { result, entry in
                guard result.contains(where: { $0.caseInsensitiveCompare(entry) == .orderedSame }) == false else {
                    return
                }
                result.append(entry)
            }

        guard pieces.isEmpty == false else {
            return nil
        }
        return pieces.joined(separator: "\n\n")
    }

    static func mergedExamples(primary: [ExampleSentence], secondary: [ExampleSentence]) -> [ExampleSentence] {
        var seen = Set<String>()
        var merged: [ExampleSentence] = []

        for example in primary + secondary {
            let key = WordNormalizer.normalizeLemma(example.sentence)
            guard seen.insert(key).inserted else {
                continue
            }
            merged.append(example)
            if merged.count == 3 {
                break
            }
        }

        return merged.enumerated().map { index, example in
            ExampleSentence(
                id: example.id,
                sentence: example.sentence,
                translation: example.translation,
                order: index + 1,
                source: example.source
            )
        }
    }

    static func mergedAudio(primary: [WordAudio], secondary: [WordAudio]) -> [WordAudio] {
        var seen = Set<String>()
        var merged: [WordAudio] = []

        for track in primary + secondary {
            let key = [
                track.url.absoluteString,
                WordNormalizer.normalizeLemma(track.accent),
                WordNormalizer.normalizeLemma(track.speed),
                WordNormalizer.normalizeLemma(track.source ?? ""),
                WordNormalizer.normalizeLemma(track.providerReference ?? "")
            ]
            .joined(separator: "|")

            guard seen.insert(key).inserted else {
                continue
            }
            merged.append(track)
        }

        return merged.sorted { lhs, rhs in
            let lhsPriority = WordAudioSortKey(track: lhs)
            let rhsPriority = WordAudioSortKey(track: rhs)
            if lhsPriority != rhsPriority {
                return lhsPriority < rhsPriority
            }
            return lhs.accent.localizedCaseInsensitiveCompare(rhs.accent) == .orderedAscending
        }
    }

    private static func uniqueStrings(_ values: [String]) -> [String] {
        values.reduce(into: [String]()) { result, value in
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedValue.isEmpty == false else {
                return
            }
            guard result.contains(where: { $0.caseInsensitiveCompare(trimmedValue) == .orderedSame }) == false else {
                return
            }
            result.append(trimmedValue)
        }
    }
}

struct CachedWordEnrichment: Codable, Equatable, Sendable {
    let wordID: UUID
    let payload: WordEnrichmentSnapshot
    let cachedAt: Date
}

struct DiscoveredWordCandidate: Equatable, Sendable {
    let languageCode: String
    let lemma: String
    let transliteration: String?
    let pronunciationIPA: String?
    let pronunciationGuidance: String?
    let partOfSpeech: String?
    let definition: String
    let usageNotes: String?
    let examples: [ExampleSentence]
    let audio: [WordAudio]
    let languageVariant: String?
    let sources: [String]
}

extension Word {
    func applying(_ snapshot: WordEnrichmentSnapshot) -> Word {
        let resolvedDefinition = Self.preferredText(definition, fallback: snapshot.definition) ?? definition
        let resolvedSupplementalDefinition = Self.resolveSupplementalDefinition(
            baseDefinition: definition,
            existingSupplementalDefinition: supplementalDefinition,
            incomingDefinition: snapshot.definition,
            incomingSupplementalDefinition: snapshot.supplementalDefinition
        )

        return Word(
            id: id,
            languageCode: languageCode,
            lemma: lemma,
            transliteration: Self.preferredText(transliteration, fallback: snapshot.transliteration),
            pronunciationIPA: Self.preferredText(
                pronunciationIPA,
                fallback: snapshot.pronunciationIPA ?? snapshot.pronunciationGuidance
            ) ?? "",
            partOfSpeech: Self.preferredText(partOfSpeech, fallback: snapshot.partOfSpeech) ?? "",
            cefrLevel: cefrLevel,
            frequencyRank: frequencyRank,
            definition: resolvedDefinition,
            usageNotes: Self.mergeParagraphs(usageNotes, snapshot.usageNotes) ?? usageNotes,
            examples: Self.mergeExamples(base: examples, enrichment: snapshot.examples),
            audio: WordEnrichmentSnapshot.mergedAudio(primary: snapshot.audio, secondary: audio),
            supplementalDefinition: resolvedSupplementalDefinition,
            pronunciationGuidance: Self.preferredText(pronunciationGuidance, fallback: snapshot.pronunciationGuidance),
            languageVariant: Self.preferredText(languageVariant, fallback: snapshot.languageVariant),
            enrichmentSources: Self.mergeSources(base: enrichmentSources, enrichment: snapshot.sources),
            enrichmentUpdatedAt: max(enrichmentUpdatedAt ?? .distantPast, snapshot.updatedAt)
        )
    }

    private static func preferredText(_ current: String?, fallback: String?) -> String? {
        let currentValue = current?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let currentValue, currentValue.isEmpty == false {
            return currentValue
        }

        let fallbackValue = fallback?.trimmingCharacters(in: .whitespacesAndNewlines)
        return fallbackValue?.isEmpty == false ? fallbackValue : nil
    }

    private static func mergeParagraphs(_ base: String, _ enrichment: String?) -> String? {
        let pieces = [base, enrichment]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .reduce(into: [String]()) { result, piece in
                guard result.contains(where: { $0.caseInsensitiveCompare(piece) == .orderedSame }) == false else {
                    return
                }
                result.append(piece)
            }

        guard pieces.isEmpty == false else {
            return nil
        }
        return pieces.joined(separator: "\n\n")
    }

    private static func mergeExamples(base: [ExampleSentence], enrichment: [ExampleSentence]) -> [ExampleSentence] {
        WordEnrichmentSnapshot.mergedExamples(primary: base, secondary: enrichment)
    }

    private static func mergeSources(base: [String]?, enrichment: [String]) -> [String]? {
        let merged = (base ?? []) + enrichment
        let uniqueValues = merged.reduce(into: [String]()) { result, value in
            let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedValue.isEmpty == false else {
                return
            }
            guard result.contains(where: { $0.caseInsensitiveCompare(trimmedValue) == .orderedSame }) == false else {
                return
            }
            result.append(trimmedValue)
        }
        return uniqueValues.isEmpty ? nil : uniqueValues
    }

    private static func resolveSupplementalDefinition(
        baseDefinition: String,
        existingSupplementalDefinition: String?,
        incomingDefinition: String?,
        incomingSupplementalDefinition: String?
    ) -> String? {
        if let incomingSupplementalDefinition = preferredText(incomingSupplementalDefinition, fallback: nil) {
            return incomingSupplementalDefinition
        }

        guard let incomingDefinition = preferredText(incomingDefinition, fallback: nil) else {
            return preferredText(existingSupplementalDefinition, fallback: nil)
        }

        let normalizedBaseDefinition = WordNormalizer.normalizeLemma(baseDefinition)
        let normalizedIncomingDefinition = WordNormalizer.normalizeLemma(incomingDefinition)
        guard normalizedBaseDefinition != normalizedIncomingDefinition else {
            return preferredText(existingSupplementalDefinition, fallback: nil)
        }

        return incomingDefinition
    }
}

private struct WordAudioSortKey: Comparable {
    let sourcePriority: Int
    let speedPriority: Int

    init(track: WordAudio) {
        switch track.source?.lowercased() {
        case "forvo":
            sourcePriority = 0
        case "google-tts":
            sourcePriority = 2
        default:
            sourcePriority = 1
        }

        switch track.speed.lowercased() {
        case "native":
            speedPriority = 0
        case "slow":
            speedPriority = 1
        default:
            speedPriority = 2
        }
    }

    static func < (lhs: WordAudioSortKey, rhs: WordAudioSortKey) -> Bool {
        if lhs.sourcePriority != rhs.sourcePriority {
            return lhs.sourcePriority < rhs.sourcePriority
        }
        return lhs.speedPriority < rhs.speedPriority
    }
}
