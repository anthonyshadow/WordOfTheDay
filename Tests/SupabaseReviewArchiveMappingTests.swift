import XCTest
@testable import LinguaDaily

final class SupabaseReviewArchiveMappingTests: XCTestCase {
    func testMakeCachedCardsBuildsReviewOptionsFromLanguagePool() throws {
        let languageID = UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!
        let progressRow = makeReviewProgressRow(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            word: makeReviewWordDTO(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                languageID: languageID,
                lemma: "bonjour",
                definition: "Hello"
            )
        )

        let cachedCards = SupabaseReviewService.makeCachedCards(
            progressRows: [progressRow],
            distractorPoolByLanguageID: [
                languageID: [
                    WordDefinitionDTO(id: progressRow.word.id, language_id: languageID, definition: "Hello"),
                    WordDefinitionDTO(id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!, language_id: languageID, definition: "Goodbye"),
                    WordDefinitionDTO(id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!, language_id: languageID, definition: "Thank you"),
                    WordDefinitionDTO(id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!, language_id: languageID, definition: "Excuse me")
                ]
            ]
        )

        XCTAssertEqual(cachedCards.count, 1)
        let card = try XCTUnwrap(cachedCards.first?.card)
        XCTAssertEqual(card.id, progressRow.id)
        XCTAssertEqual(card.wordID, progressRow.word_id)
        XCTAssertEqual(card.lemma, "bonjour")
        XCTAssertEqual(card.correctMeaning, "Hello")
        XCTAssertEqual(card.options.count, 4)
        XCTAssertEqual(card.options.filter(\.isCorrect).map(\.text), ["Hello"])
        XCTAssertEqual(Set(card.options.map(\.text)), ["Hello", "Goodbye", "Thank you", "Excuse me"])
    }

    func testMakeReviewedProgressAdvancesCorrectReviewAndKeepsSavedFlag() {
        let now = Date(timeIntervalSince1970: 1_720_000_000)
        let existing = makeProgressDTO(
            wordID: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            status: .learned,
            isFavorited: true,
            isSavedForReview: true,
            totalReviews: 4,
            correctReviews: 3,
            consecutiveCorrect: 3,
            currentIntervalDays: 7,
            nextReviewAt: now
        )
        let schedule = ReviewScheduler().schedule(
            previousIntervalDays: existing.current_interval_days,
            consecutiveCorrect: existing.consecutive_correct,
            totalReviews: existing.total_reviews,
            wasCorrect: true,
            referenceDate: now
        )

        let reviewed = SupabaseReviewService.makeReviewedProgress(
            userID: existing.user_id,
            wordID: existing.word_id,
            existing: existing,
            wasCorrect: true,
            schedule: schedule,
            now: now
        )

        XCTAssertEqual(reviewed.status, .mastered)
        XCTAssertTrue(reviewed.is_favorited)
        XCTAssertTrue(reviewed.is_saved_for_review)
        XCTAssertEqual(reviewed.total_reviews, 5)
        XCTAssertEqual(reviewed.correct_reviews, 4)
        XCTAssertEqual(reviewed.consecutive_correct, 4)
        XCTAssertEqual(reviewed.current_interval_days, 14)
        XCTAssertEqual(reviewed.last_reviewed_at, now)
        XCTAssertEqual(reviewed.learned_at, existing.learned_at)
    }

    func testMakeArchiveWordsDerivesDayNumbersAndDueStatus() {
        let language = makeLanguageDTO()
        let firstWord = makeWordDTO(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            lemma: "bonjour",
            definition: "Hello",
            language: language
        )
        let secondWord = makeWordDTO(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            lemma: "merci",
            definition: "Thank you",
            language: language
        )
        let assignments = [
            DailyWordAssignmentWithWordDTO(
                id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                assignment_date: "2026-03-20",
                word: firstWord
            ),
            DailyWordAssignmentWithWordDTO(
                id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                assignment_date: "2026-03-21",
                word: secondWord
            )
        ]
        let referenceDate = Date(timeIntervalSince1970: 1_742_560_000)
        let progress = [
            makeProgressDTO(
                wordID: firstWord.id,
                status: .learned,
                isFavorited: true,
                isSavedForReview: true,
                totalReviews: 2,
                correctReviews: 1,
                consecutiveCorrect: 1,
                currentIntervalDays: 1,
                nextReviewAt: referenceDate.addingTimeInterval(-60)
            )
        ]

        let archiveWords = SupabaseArchiveService.makeArchiveWords(
            assignments: assignments,
            progress: progress,
            referenceDate: referenceDate
        )

        XCTAssertEqual(archiveWords.count, 2)
        XCTAssertEqual(archiveWords[0].word.lemma, "bonjour")
        XCTAssertEqual(archiveWords[0].dayNumber, 1)
        XCTAssertEqual(archiveWords[0].status, .reviewDue)
        XCTAssertTrue(archiveWords[0].isFavorited)
        XCTAssertEqual(archiveWords[1].word.lemma, "merci")
        XCTAssertEqual(archiveWords[1].dayNumber, 2)
        XCTAssertEqual(archiveWords[1].status, .new)
    }

    func testFilterAndSortArchiveHonorsFavoritesAndQuery() {
        let words = [
            ArchiveWord(
                id: UUID(),
                word: SampleData.words[0],
                status: .learned,
                dayNumber: 3,
                isFavorited: true,
                nextReviewAt: nil,
                learnedAt: Date()
            ),
            ArchiveWord(
                id: UUID(),
                word: SampleData.words[6],
                status: .reviewDue,
                dayNumber: 1,
                isFavorited: false,
                nextReviewAt: Date().addingTimeInterval(300),
                learnedAt: Date()
            )
        ]

        let filtered = SupabaseArchiveService.filterAndSortArchive(
            words: words,
            filter: .favorites,
            sort: .alphabetical,
            query: "hello"
        )

        XCTAssertEqual(filtered.count, 1)
        XCTAssertEqual(filtered.first?.word.lemma, SampleData.words[0].lemma)
    }

    private func makeReviewProgressRow(id: UUID, word: ReviewWordDTO) -> UserWordProgressWithWordDTO {
        UserWordProgressWithWordDTO(
            id: id,
            user_id: UUID(uuidString: "99999999-9999-9999-9999-999999999999")!,
            word_id: word.id,
            status: .reviewDue,
            is_favorited: false,
            is_saved_for_review: true,
            consecutive_correct: 1,
            total_reviews: 2,
            correct_reviews: 1,
            current_interval_days: 1,
            next_review_at: Date(timeIntervalSince1970: 1_720_000_000),
            learned_at: Date(timeIntervalSince1970: 1_710_000_000),
            last_reviewed_at: Date(timeIntervalSince1970: 1_719_000_000),
            word: word
        )
    }

    private func makeReviewWordDTO(id: UUID, languageID: UUID, lemma: String, definition: String) -> ReviewWordDTO {
        ReviewWordDTO(
            id: id,
            language_id: languageID,
            lemma: lemma,
            pronunciation_ipa: "/test/",
            definition: definition
        )
    }

    private func makeProgressDTO(
        wordID: UUID,
        status: WordStatus,
        isFavorited: Bool,
        isSavedForReview: Bool,
        totalReviews: Int,
        correctReviews: Int,
        consecutiveCorrect: Int,
        currentIntervalDays: Int,
        nextReviewAt: Date?
    ) -> UserWordProgressDTO {
        UserWordProgressDTO(
            id: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            user_id: UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
            word_id: wordID,
            status: status,
            is_favorited: isFavorited,
            is_saved_for_review: isSavedForReview,
            consecutive_correct: consecutiveCorrect,
            total_reviews: totalReviews,
            correct_reviews: correctReviews,
            current_interval_days: currentIntervalDays,
            next_review_at: nextReviewAt,
            learned_at: Date(timeIntervalSince1970: 1_700_000_000),
            last_reviewed_at: Date(timeIntervalSince1970: 1_710_000_000)
        )
    }

    private func makeLanguageDTO() -> LanguageDTO {
        LanguageDTO(
            id: UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
            code: "fr",
            name: "French",
            native_name: "Francais",
            is_active: true
        )
    }

    private func makeWordDTO(id: UUID, lemma: String, definition: String, language: LanguageDTO) -> WordWithRelationsDTO {
        WordWithRelationsDTO(
            id: id,
            lemma: lemma,
            transliteration: nil,
            pronunciation_ipa: "/test/",
            part_of_speech: "interjection",
            cefr_level: "A1",
            frequency_rank: 1,
            definition: definition,
            usage_notes: "Common usage",
            language: language,
            example_sentences: [
                ExampleSentenceDTO(
                    id: UUID(),
                    word_id: id,
                    sentence: "\(lemma.capitalized)!",
                    translation: definition,
                    order_index: 1
                )
            ],
            word_audio: []
        )
    }
}
