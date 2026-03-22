import Foundation

protocol WordEnrichmentCoordinating {
    func enrich(_ lesson: DailyLesson, preferredAccent: String?) async -> DailyLesson
}

final class WordEnrichmentCoordinator: WordEnrichmentCoordinating {
    private let wiktionaryClient: WiktionaryAPIClientProtocol?
    private let forvoClient: ForvoAPIClientProtocol?
    private let googleTextToSpeechClient: GoogleTextToSpeechClientProtocol?
    private let cacheStore: LocalCacheStore?
    private let persistenceService: WordCatalogPersisting?
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let now: @Sendable () -> Date
    private let cacheTTL: TimeInterval

    init(
        wiktionaryClient: WiktionaryAPIClientProtocol?,
        forvoClient: ForvoAPIClientProtocol?,
        googleTextToSpeechClient: GoogleTextToSpeechClientProtocol?,
        cacheStore: LocalCacheStore?,
        persistenceService: WordCatalogPersisting?,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        cacheTTL: TimeInterval = 7 * 24 * 60 * 60,
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.wiktionaryClient = wiktionaryClient
        self.forvoClient = forvoClient
        self.googleTextToSpeechClient = googleTextToSpeechClient
        self.cacheStore = cacheStore
        self.persistenceService = persistenceService
        self.analytics = analytics
        self.crash = crash
        self.cacheTTL = cacheTTL
        self.now = now
    }

    func enrich(_ lesson: DailyLesson, preferredAccent: String?) async -> DailyLesson {
        let cachedEnrichment = await loadCachedEnrichment(for: lesson.word.id)
        if let cachedEnrichment, isFresh(cachedEnrichment.cachedAt) {
            return lessonWithEnrichment(lesson, payload: cachedEnrichment.payload)
        }

        async let wiktionaryTask = fetchWiktionary(for: lesson.word)
        async let forvoTask = fetchForvo(for: lesson.word, preferredAccent: preferredAccent)
        async let googleTask = fetchGoogleTextToSpeechIfNeeded(
            for: lesson.word,
            preferredAccent: preferredAccent
        )

        let wiktionaryPayload = await wiktionaryTask
        let forvoTracks = await forvoTask
        let googleTrack = await googleTask

        var payload = WordEnrichmentSnapshot.empty(updatedAt: now())

        if let cachedEnrichment, isFresh(cachedEnrichment.cachedAt) == false {
            payload = payload.merged(with: cachedEnrichment.payload)
        }

        if let wiktionaryPayload {
            payload = payload.merged(with: wiktionaryPayload)
        }

        if forvoTracks.isEmpty == false {
            payload = payload.merged(
                with: WordEnrichmentSnapshot(
                    lemma: nil,
                    transliteration: nil,
                    pronunciationIPA: nil,
                    partOfSpeech: nil,
                    definition: nil,
                    supplementalDefinition: nil,
                    usageNotes: nil,
                    examples: [],
                    audio: forvoTracks,
                    pronunciationGuidance: nil,
                    languageVariant: nil,
                    sources: ["forvo"],
                    updatedAt: now()
                )
            )
        } else if let googleTrack {
            payload = payload.merged(
                with: WordEnrichmentSnapshot(
                    lemma: nil,
                    transliteration: nil,
                    pronunciationIPA: nil,
                    partOfSpeech: nil,
                    definition: nil,
                    supplementalDefinition: nil,
                    usageNotes: nil,
                    examples: [],
                    audio: [googleTrack],
                    pronunciationGuidance: nil,
                    languageVariant: nil,
                    sources: ["google-tts"],
                    updatedAt: now()
                )
            )
        }

        guard payload.hasMeaningfulContent else {
            if let cachedEnrichment {
                return lessonWithEnrichment(lesson, payload: cachedEnrichment.payload)
            }
            return lesson
        }

        await saveCachedEnrichment(payload, for: lesson.word.id)

        if let candidate = discoveredWordCandidate(baseWord: lesson.word, payload: payload) {
            Task(priority: .utility) { [persistenceService] in
                await persistenceService?.persistIfNeeded(candidate: candidate, baseWord: lesson.word)
            }
        }

        return lessonWithEnrichment(lesson, payload: payload)
    }

    private func fetchWiktionary(for word: Word) async -> WordEnrichmentSnapshot? {
        guard let wiktionaryClient else {
            return nil
        }

        do {
            let payload = try await wiktionaryClient.fetchEnrichment(for: word.lemma, languageCode: word.languageCode)
            if payload?.hasMeaningfulContent == true {
                analytics.track(.enrichmentProviderSucceeded, properties: [
                    "provider": "wiktionary",
                    "word": word.lemma,
                    "language": word.languageCode
                ])
            }
            return payload
        } catch {
            reportProviderFailure(
                provider: "wiktionary",
                tag: Self.wiktionaryTag(for: error),
                error: error,
                word: word
            )
            return nil
        }
    }

    private func fetchForvo(for word: Word, preferredAccent: String?) async -> [WordAudio] {
        guard let forvoClient else {
            return []
        }

        do {
            let tracks = try await forvoClient.fetchPronunciationAudio(
                for: word.lemma,
                languageCode: word.languageCode,
                preferredAccent: preferredAccent
            )

            if tracks.isEmpty == false {
                analytics.track(.enrichmentProviderSucceeded, properties: [
                    "provider": "forvo",
                    "word": word.lemma,
                    "language": word.languageCode,
                    "count": "\(tracks.count)"
                ])
            }

            return tracks
        } catch {
            reportProviderFailure(
                provider: "forvo",
                tag: Self.forvoTag(for: error),
                error: error,
                word: word
            )
            return []
        }
    }

    private func fetchGoogleTextToSpeechIfNeeded(for word: Word, preferredAccent: String?) async -> WordAudio? {
        guard word.audio.isEmpty, let googleTextToSpeechClient else {
            return nil
        }

        do {
            let track = try await googleTextToSpeechClient.synthesizePronunciation(
                for: word.lemma,
                languageCode: word.languageCode,
                preferredAccent: preferredAccent
            )

            if track != nil {
                analytics.track(.enrichmentProviderSucceeded, properties: [
                    "provider": "google-tts",
                    "word": word.lemma,
                    "language": word.languageCode
                ])
            }

            return track
        } catch {
            reportProviderFailure(
                provider: "google-tts",
                tag: Self.googleTextToSpeechTag(for: error),
                error: error,
                word: word
            )
            return nil
        }
    }

    private func discoveredWordCandidate(baseWord: Word, payload: WordEnrichmentSnapshot) -> DiscoveredWordCandidate? {
        guard let candidateLemma = payload.lemma?.trimmingCharacters(in: .whitespacesAndNewlines),
              candidateLemma.isEmpty == false,
              WordNormalizer.normalizeLemma(candidateLemma) != WordNormalizer.normalizeLemma(baseWord.lemma),
              let definition = payload.definition?.trimmingCharacters(in: .whitespacesAndNewlines),
              definition.isEmpty == false else {
            return nil
        }

        return DiscoveredWordCandidate(
            languageCode: baseWord.languageCode,
            lemma: candidateLemma,
            transliteration: payload.transliteration,
            pronunciationIPA: payload.pronunciationIPA,
            pronunciationGuidance: payload.pronunciationGuidance,
            partOfSpeech: payload.partOfSpeech,
            definition: definition,
            usageNotes: payload.usageNotes,
            examples: payload.examples,
            audio: payload.audio,
            languageVariant: payload.languageVariant,
            sources: payload.sources
        )
    }

    private func lessonWithEnrichment(_ lesson: DailyLesson, payload: WordEnrichmentSnapshot) -> DailyLesson {
        DailyLesson(
            id: lesson.id,
            assignmentDate: lesson.assignmentDate,
            dayNumber: lesson.dayNumber,
            languageName: lesson.languageName,
            word: lesson.word.applying(payload),
            isLearned: lesson.isLearned,
            isFavorited: lesson.isFavorited,
            isSavedForReview: lesson.isSavedForReview
        )
    }

    private func isFresh(_ date: Date) -> Bool {
        now().timeIntervalSince(date) <= cacheTTL
    }

    private func loadCachedEnrichment(for wordID: UUID) async -> CachedWordEnrichment? {
        guard let cacheStore else {
            return nil
        }

        return await MainActor.run {
            try? cacheStore.loadWordEnrichment(for: wordID)
        }
    }

    private func saveCachedEnrichment(_ payload: WordEnrichmentSnapshot, for wordID: UUID) async {
        guard let cacheStore else {
            return
        }

        let cutoffDate = now().addingTimeInterval(-cacheTTL)
        await MainActor.run {
            try? cacheStore.saveWordEnrichment(payload, for: wordID)
            try? cacheStore.removeExpiredWordEnrichments(olderThan: cutoffDate)
        }
    }

    private func reportProviderFailure(provider: String, tag: String, error: Error, word: Word) {
        crash.capture(error, context: [
            "feature": "word_enrichment",
            "provider": provider,
            "tag": tag,
            "word": word.lemma,
            "language": word.languageCode
        ])
        analytics.track(.enrichmentProviderFailed, properties: [
            "provider": provider,
            "tag": tag,
            "word": word.lemma,
            "language": word.languageCode
        ])
    }

    private static func wiktionaryTag(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return "wiktionary_timeout"
        }

        if let appError = error as? AppError, case .decoding = appError {
            return "wiktionary_parse_error"
        }

        return "wiktionary_error"
    }

    private static func forvoTag(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return "forvo_timeout"
        }

        if let appError = error as? AppError,
           case let .auth(message) = appError,
           message.localizedCaseInsensitiveContains("forvo") {
            return "forvo_401"
        }

        return "forvo_error"
    }

    private static func googleTextToSpeechTag(for error: Error) -> String {
        if let urlError = error as? URLError, urlError.code == .timedOut {
            return "gcp_tts_timeout"
        }

        return "gcp_tts_error"
    }
}
