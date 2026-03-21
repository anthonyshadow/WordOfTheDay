import Foundation
import Supabase

final class SupabaseReviewService: ReviewServiceProtocol {
    private let client: SupabaseClient
    private let scheduler = ReviewScheduler()
    private var cachedCards: [UUID: CachedReviewCard] = [:]

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchReviewQueue() async throws -> [ReviewCard] {
        let userID = try await currentUserID()
        let referenceDate = Date()
        let progressRows = try await fetchReviewProgress(userID: userID)
        let dueRows = progressRows
            .filter { Self.isDueForReview(progress: $0.progress, referenceDate: referenceDate) }
            .sorted { Self.reviewSort(lhs: $0, rhs: $1) }

        guard !dueRows.isEmpty else {
            cachedCards = [:]
            return []
        }

        try await ensureQueuedReviewsExist(for: dueRows, userID: userID, referenceDate: referenceDate)
        let distractorPoolByLanguageID = try await fetchDistractorPool(languageIDs: Set(dueRows.map(\.word.language_id)))
        let cards = Self.makeCachedCards(progressRows: dueRows, distractorPoolByLanguageID: distractorPoolByLanguageID)
        cachedCards = Dictionary(uniqueKeysWithValues: cards.map { ($0.card.id, $0) })
        return cards.map(\.card)
    }

    func submitAnswer(cardID: UUID, selectedOptionID: UUID) async throws -> ReviewFeedback {
        guard let cachedCard = cachedCards[cardID] else {
            throw AppError.validation("Review card missing")
        }

        guard let selectedOption = cachedCard.card.options.first(where: { $0.id == selectedOptionID }) else {
            throw AppError.validation("Selected option missing")
        }

        let referenceDate = Date()
        let schedule = scheduler.schedule(
            previousIntervalDays: cachedCard.progress.current_interval_days,
            consecutiveCorrect: cachedCard.progress.consecutive_correct,
            totalReviews: cachedCard.progress.total_reviews,
            wasCorrect: selectedOption.isCorrect,
            referenceDate: referenceDate
        )
        let reviewedProgress = Self.makeReviewedProgress(
            userID: cachedCard.userID,
            wordID: cachedCard.card.wordID,
            existing: cachedCard.progress,
            wasCorrect: selectedOption.isCorrect,
            schedule: schedule,
            now: referenceDate
        )

        do {
            try await client
                .from("user_word_progress")
                .upsert(reviewedProgress, onConflict: "user_id,word_id", returning: .minimal)
                .execute()

            try await completeQueuedReview(
                userID: cachedCard.userID,
                wordID: cachedCard.card.wordID,
                selectedOption: selectedOption.text,
                wasCorrect: selectedOption.isCorrect,
                totalReviews: reviewedProgress.total_reviews
            )

            if reviewedProgress.is_saved_for_review {
                try await insertQueuedReview(
                    userID: cachedCard.userID,
                    wordID: cachedCard.card.wordID,
                    dueAt: reviewedProgress.next_review_at ?? schedule.nextReviewAt,
                    attemptCount: reviewedProgress.total_reviews
                )
            }

            cachedCards.removeValue(forKey: cardID)
            return Self.makeFeedback(card: cachedCard.card, selectedOption: selectedOption, nextReviewDate: schedule.nextReviewAt)
        } catch {
            throw normalize(error)
        }
    }

    private func currentUserID() async throws -> UUID {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw normalize(error)
        }
    }

    private func fetchReviewProgress(userID: UUID) async throws -> [UserWordProgressWithWordDTO] {
        do {
            return try await client
                .from("user_word_progress")
                .select(Self.progressSelect)
                .eq("user_id", value: userID)
                .eq("is_saved_for_review", value: true)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func fetchQueuedReviews(userID: UUID, wordID: UUID? = nil) async throws -> [ReviewQueueRowDTO] {
        do {
            var query = client
                .from("review_queue")
                .select("id,user_id,word_id,due_at,state,last_outcome_correct,attempt_count,selected_option")
                .eq("user_id", value: userID)
                .eq("state", value: "queued")

            if let wordID {
                query = query.eq("word_id", value: wordID)
            }

            return try await query
                .order("due_at", ascending: true)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func fetchDistractorPool(languageIDs: Set<UUID>) async throws -> [UUID: [WordDefinitionDTO]] {
        guard !languageIDs.isEmpty else {
            return [:]
        }

        var poolByLanguageID: [UUID: [WordDefinitionDTO]] = [:]
        for languageID in languageIDs {
            do {
                let rows: [WordDefinitionDTO] = try await client
                    .from("words")
                    .select("id,language_id,definition")
                    .eq("language_id", value: languageID)
                    .order("frequency_rank", ascending: true)
                    .execute()
                    .value
                poolByLanguageID[languageID] = rows
            } catch {
                throw normalize(error)
            }
        }

        return poolByLanguageID
    }

    private func ensureQueuedReviewsExist(
        for dueRows: [UserWordProgressWithWordDTO],
        userID: UUID,
        referenceDate: Date
    ) async throws {
        let existingQueuedRows = try await fetchQueuedReviews(userID: userID)
        let queuedWordIDs = Set(existingQueuedRows.map(\.word_id))

        for row in dueRows where !queuedWordIDs.contains(row.word_id) {
            try await insertQueuedReview(
                userID: userID,
                wordID: row.word_id,
                dueAt: row.next_review_at ?? referenceDate,
                attemptCount: row.total_reviews
            )
        }
    }

    private func insertQueuedReview(userID: UUID, wordID: UUID, dueAt: Date, attemptCount: Int) async throws {
        do {
            try await client
                .from("review_queue")
                .insert(
                    ReviewQueueInsertDTO(
                        user_id: userID,
                        word_id: wordID,
                        due_at: dueAt,
                        attempt_count: attemptCount
                    ),
                    returning: .minimal
                )
                .execute()
        } catch {
            throw normalize(error)
        }
    }

    private func completeQueuedReview(
        userID: UUID,
        wordID: UUID,
        selectedOption: String,
        wasCorrect: Bool,
        totalReviews: Int
    ) async throws {
        guard let queuedRow = try await fetchQueuedReviews(userID: userID, wordID: wordID).first else {
            return
        }

        do {
            try await client
                .from("review_queue")
                .update(
                    ReviewQueueCompletionUpdateDTO(
                        last_outcome_correct: wasCorrect,
                        attempt_count: max(totalReviews, queuedRow.attempt_count + 1),
                        selected_option: selectedOption
                    ),
                    returning: .minimal
                )
                .eq("id", value: queuedRow.id)
                .execute()
        } catch {
            throw normalize(error)
        }
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? "Could not load your review queue." : message)
    }

    private static var progressSelect: String {
        """
        id,
        user_id,
        word_id,
        status,
        is_favorited,
        is_saved_for_review,
        consecutive_correct,
        total_reviews,
        correct_reviews,
        current_interval_days,
        next_review_at,
        learned_at,
        last_reviewed_at,
        word:words!user_word_progress_word_id_fkey(
            id,
            language_id,
            lemma,
            pronunciation_ipa,
            definition
        )
        """
    }

    private static func reviewSort(lhs: UserWordProgressWithWordDTO, rhs: UserWordProgressWithWordDTO) -> Bool {
        let lhsDueAt = lhs.next_review_at ?? .distantPast
        let rhsDueAt = rhs.next_review_at ?? .distantPast
        if lhsDueAt != rhsDueAt {
            return lhsDueAt < rhsDueAt
        }
        return lhs.word.lemma.localizedCaseInsensitiveCompare(rhs.word.lemma) == .orderedAscending
    }

    static func isDueForReview(progress: UserWordProgressDTO, referenceDate: Date = .now) -> Bool {
        guard progress.is_saved_for_review else {
            return false
        }

        guard let nextReviewAt = progress.next_review_at else {
            return true
        }

        return nextReviewAt <= referenceDate
    }

    static func makeCachedCards(
        progressRows: [UserWordProgressWithWordDTO],
        distractorPoolByLanguageID: [UUID: [WordDefinitionDTO]]
    ) -> [CachedReviewCard] {
        progressRows.map { row in
            let options = makeOptions(
                correctWord: row.word,
                distractorPool: distractorPoolByLanguageID[row.word.language_id] ?? []
            )
            let card = ReviewCard(
                id: row.id,
                wordID: row.word_id,
                lemma: row.word.lemma,
                pronunciation: row.word.pronunciation_ipa ?? "",
                options: options,
                correctMeaning: row.word.definition
            )
            return CachedReviewCard(userID: row.user_id, progress: row.progress, card: card)
        }
    }

    static func makeReviewedProgress(
        userID: UUID,
        wordID: UUID,
        existing: UserWordProgressDTO,
        wasCorrect: Bool,
        schedule: (nextIntervalDays: Int, nextReviewAt: Date, nextConsecutiveCorrect: Int, nextStatus: WordStatus),
        now: Date = .now
    ) -> UserWordProgressUpsertDTO {
        UserWordProgressUpsertDTO(
            user_id: userID,
            word_id: wordID,
            status: schedule.nextStatus,
            is_favorited: existing.is_favorited,
            is_saved_for_review: existing.is_saved_for_review,
            consecutive_correct: schedule.nextConsecutiveCorrect,
            total_reviews: existing.total_reviews + 1,
            correct_reviews: existing.correct_reviews + (wasCorrect ? 1 : 0),
            current_interval_days: schedule.nextIntervalDays,
            next_review_at: schedule.nextReviewAt,
            learned_at: existing.learned_at ?? now,
            last_reviewed_at: now
        )
    }

    static func makeFeedback(
        card: ReviewCard,
        selectedOption: ReviewOption,
        nextReviewDate: Date
    ) -> ReviewFeedback {
        ReviewFeedback(
            isCorrect: selectedOption.isCorrect,
            explanation: selectedOption.isCorrect ? "Correct" : "Correct meaning: \(card.correctMeaning)",
            nextReviewDate: nextReviewDate
        )
    }

    private static func makeOptions(correctWord: ReviewWordDTO, distractorPool: [WordDefinitionDTO]) -> [ReviewOption] {
        var distractorTexts: [String] = []
        for candidate in distractorPool where candidate.id != correctWord.id {
            let definition = candidate.definition.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !definition.isEmpty else {
                continue
            }
            guard definition.caseInsensitiveCompare(correctWord.definition) != .orderedSame else {
                continue
            }
            guard !distractorTexts.contains(where: { $0.caseInsensitiveCompare(definition) == .orderedSame }) else {
                continue
            }

            distractorTexts.append(definition)
            if distractorTexts.count == 3 {
                break
            }
        }

        var options = distractorTexts.map {
            ReviewOption(id: UUID(), text: $0, isCorrect: false)
        }
        let correctOption = ReviewOption(id: UUID(), text: correctWord.definition, isCorrect: true)
        let insertionIndex = min(options.count, max(0, options.count / 2))
        options.insert(correctOption, at: insertionIndex)
        return options
    }
}

struct CachedReviewCard {
    let userID: UUID
    let progress: UserWordProgressDTO
    let card: ReviewCard
}
