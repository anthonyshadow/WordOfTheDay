import Foundation
import Supabase

final class SupabaseDailyLessonService: DailyLessonServiceProtocol {
    private let client: SupabaseClient
    private let assigner = DailyWordAssigner()

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchTodayLesson() async throws -> DailyLesson {
        let userID = try await currentUserID()
        let today = Date()
        let todayKey = SupabaseFieldParser.sqlDateString(from: today)

        if let assignment = try await fetchAssignment(userID: userID, assignmentDateKey: todayKey) {
            let progress = try await fetchProgress(userID: userID, wordID: assignment.word.id)
            let dayNumber = try await fetchAssignmentCount(userID: userID)
            return Self.makeLesson(
                assignmentID: assignment.id,
                assignmentDateKey: assignment.assignment_date,
                dayNumber: max(dayNumber, 1),
                word: assignment.word,
                progress: progress,
                fallbackDate: today
            )
        }

        return try await createLessonForToday(userID: userID, today: today, assignmentDateKey: todayKey)
    }

    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws {
        let userID = try await currentUserID()
        let existing = try await fetchProgress(userID: userID, wordID: wordID)
        let now = Date()
        let merged = Self.mergeProgress(
            userID: userID,
            wordID: wordID,
            existing: existing,
            isLearned: isLearned,
            isFavorited: isFavorited,
            isSavedForReview: isSavedForReview,
            now: now
        )

        do {
            try await client
                .from("user_word_progress")
                .upsert(
                    merged,
                    onConflict: "user_id,word_id",
                    returning: .minimal
                )
                .execute()

            if isSavedForReview != nil {
                try await syncReviewQueue(
                    userID: userID,
                    wordID: wordID,
                    mergedProgress: merged,
                    referenceDate: now
                )
            }
        } catch {
            throw normalize(error)
        }
    }

    func fetchWordDetail(wordID: UUID) async throws -> Word {
        guard let word = try await fetchWord(wordID: wordID) else {
            throw AppError.network("Word not found.")
        }

        return word.toModel()
    }

    func fetchWordProgressState(wordID: UUID) async throws -> WordProgressState {
        let userID = try await currentUserID()
        let progress = try await fetchProgress(userID: userID, wordID: wordID)
        return Self.makeWordProgressState(progress: progress)
    }

    func fetchRelatedWords(wordID: UUID, limit: Int) async throws -> [Word] {
        guard limit > 0, let referenceWord = try await fetchWord(wordID: wordID) else {
            return []
        }

        guard let languageID = referenceWord.language?.id else {
            return []
        }

        let words = try await fetchWords(languageID: languageID)
        return Self.makeRelatedWords(
            from: words,
            referenceWordID: wordID,
            partOfSpeech: referenceWord.part_of_speech,
            cefrLevel: referenceWord.cefr_level,
            frequencyRank: referenceWord.frequency_rank ?? .max,
            limit: limit
        )
        .map { $0.toModel() }
    }

    private func createLessonForToday(userID: UUID, today: Date, assignmentDateKey: String) async throws -> DailyLesson {
        let assignedWordIDs = try await fetchAssignedWordIDs(userID: userID)
        let languageID = try await resolveActiveLanguageID(userID: userID)
        let words = try await fetchWords(languageID: languageID)

        let candidates = words.map { $0.toModel() }
        guard let selectedWord = assigner.assignWord(allWords: candidates, alreadyAssignedWordIDs: assignedWordIDs) else {
            throw AppError.network("No lessons are available yet.")
        }

        guard let selectedRow = words.first(where: { $0.id == selectedWord.id }) else {
            throw AppError.decoding("Could not load the selected word.")
        }

        let existingProgress = try await fetchProgress(userID: userID, wordID: selectedRow.id)
        let assignmentCount = try await fetchAssignmentCount(userID: userID)

        // The current schema disallows reassigning the same word twice, so when the seed pool is
        // exhausted we surface the recycled candidate without creating a duplicate assignment row.
        if assignedWordIDs.contains(selectedRow.id) {
            return Self.makeLesson(
                assignmentID: selectedRow.id,
                assignmentDateKey: assignmentDateKey,
                dayNumber: max(assignmentCount, 1),
                word: selectedRow,
                progress: existingProgress,
                fallbackDate: today
            )
        }

        do {
            try await client
                .from("daily_word_assignments")
                .insert(
                    DailyWordAssignmentInsertDTO(
                        user_id: userID,
                        word_id: selectedRow.id,
                        assignment_date: assignmentDateKey
                    ),
                    returning: .minimal
                )
                .execute()
        } catch {
            if let assignment = try await fetchAssignment(userID: userID, assignmentDateKey: assignmentDateKey) {
                let progress = try await fetchProgress(userID: userID, wordID: assignment.word.id)
                let dayNumber = try await fetchAssignmentCount(userID: userID)
                return Self.makeLesson(
                    assignmentID: assignment.id,
                    assignmentDateKey: assignment.assignment_date,
                    dayNumber: max(dayNumber, 1),
                    word: assignment.word,
                    progress: progress,
                    fallbackDate: today
                )
            }
            throw normalize(error)
        }

        guard let assignment = try await fetchAssignment(userID: userID, assignmentDateKey: assignmentDateKey) else {
            throw AppError.network("Could not create today's lesson.")
        }

        let dayNumber = max(try await fetchAssignmentCount(userID: userID), 1)
        return Self.makeLesson(
            assignmentID: assignment.id,
            assignmentDateKey: assignment.assignment_date,
            dayNumber: dayNumber,
            word: assignment.word,
            progress: try await fetchProgress(userID: userID, wordID: assignment.word.id),
            fallbackDate: today
        )
    }

    private func currentUserID() async throws -> UUID {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw normalize(error)
        }
    }

    private func fetchAssignment(userID: UUID, assignmentDateKey: String) async throws -> DailyWordAssignmentWithWordDTO? {
        do {
            let rows: [DailyWordAssignmentWithWordDTO] = try await client
                .from("daily_word_assignments")
                .select(Self.assignmentSelect)
                .eq("user_id", value: userID)
                .eq("assignment_date", value: assignmentDateKey)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw normalize(error)
        }
    }

    private func fetchWord(wordID: UUID) async throws -> WordWithRelationsDTO? {
        do {
            let rows: [WordWithRelationsDTO] = try await client
                .from("words")
                .select(Self.wordSelect)
                .eq("id", value: wordID)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw normalize(error)
        }
    }

    private func fetchWords(languageID: UUID) async throws -> [WordWithRelationsDTO] {
        do {
            return try await client
                .from("words")
                .select(Self.wordSelect)
                .eq("language_id", value: languageID)
                .order("frequency_rank", ascending: true)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func fetchAssignedWordIDs(userID: UUID) async throws -> Set<UUID> {
        do {
            let rows: [DailyWordAssignmentDTO] = try await client
                .from("daily_word_assignments")
                .select("id,user_id,word_id,assignment_date,source")
                .eq("user_id", value: userID)
                .execute()
                .value
            return Set(rows.map(\.word_id))
        } catch {
            throw normalize(error)
        }
    }

    private func fetchAssignmentCount(userID: UUID) async throws -> Int {
        do {
            let response = try await client
                .from("daily_word_assignments")
                .select("id", head: true, count: .exact)
                .eq("user_id", value: userID)
                .execute()
            return response.count ?? 0
        } catch {
            throw normalize(error)
        }
    }

    private func fetchProgress(userID: UUID, wordID: UUID) async throws -> UserWordProgressDTO? {
        do {
            let rows: [UserWordProgressDTO] = try await client
                .from("user_word_progress")
                .select("""
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
                    last_reviewed_at
                """)
                .eq("user_id", value: userID)
                .eq("word_id", value: wordID)
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw normalize(error)
        }
    }

    private func fetchQueuedReview(userID: UUID, wordID: UUID) async throws -> ReviewQueueRowDTO? {
        do {
            let rows: [ReviewQueueRowDTO] = try await client
                .from("review_queue")
                .select("id,user_id,word_id,due_at,state,last_outcome_correct,attempt_count,selected_option")
                .eq("user_id", value: userID)
                .eq("word_id", value: wordID)
                .eq("state", value: "queued")
                .limit(1)
                .execute()
                .value
            return rows.first
        } catch {
            throw normalize(error)
        }
    }

    private func syncReviewQueue(
        userID: UUID,
        wordID: UUID,
        mergedProgress: UserWordProgressUpsertDTO,
        referenceDate: Date
    ) async throws {
        if mergedProgress.is_saved_for_review {
            let dueAt = mergedProgress.next_review_at ?? referenceDate
            if let queuedReview = try await fetchQueuedReview(userID: userID, wordID: wordID) {
                try await client
                    .from("review_queue")
                    .update(ReviewQueueDueAtUpdateDTO(due_at: dueAt), returning: .minimal)
                    .eq("id", value: queuedReview.id)
                    .execute()
            } else {
                try await client
                    .from("review_queue")
                    .insert(
                        ReviewQueueInsertDTO(
                            user_id: userID,
                            word_id: wordID,
                            due_at: dueAt,
                            attempt_count: mergedProgress.total_reviews
                        ),
                        returning: .minimal
                    )
                    .execute()
            }
            return
        }

        if let queuedReview = try await fetchQueuedReview(userID: userID, wordID: wordID) {
            try await client
                .from("review_queue")
                .update(ReviewQueueStateUpdateDTO(state: "skipped"), returning: .minimal)
                .eq("id", value: queuedReview.id)
                .execute()
        }
    }

    private func resolveActiveLanguageID(userID: UUID) async throws -> UUID {
        do {
            let profiles: [ProfileLanguageSelectionDTO] = try await client
                .from("profiles")
                .select("active_language_id")
                .eq("id", value: userID)
                .limit(1)
                .execute()
                .value

            if let activeLanguageID = profiles.first?.active_language_id {
                return activeLanguageID
            }

            let languages: [LanguageDTO] = try await client
                .from("languages")
                .select("id,code,name,native_name,is_active")
                .eq("is_active", value: true)
                .order("name", ascending: true)
                .limit(1)
                .execute()
                .value

            if let languageID = languages.first?.id {
                return languageID
            }

            throw AppError.network("No active language is configured yet.")
        } catch {
            throw normalize(error)
        }
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? "Could not reach Supabase." : message)
    }

    private static var wordSelect: String {
        """
        id,
        lemma,
        transliteration,
        pronunciation_ipa,
        part_of_speech,
        cefr_level,
        frequency_rank,
        definition,
        usage_notes,
        language:languages!words_language_id_fkey(
            id,
            code,
            name,
            native_name,
            is_active
        ),
        example_sentences(
            id,
            word_id,
            sentence,
            translation,
            order_index
        ),
        word_audio(
            id,
            word_id,
            accent,
            speed,
            audio_url,
            duration_ms
        )
        """
    }

    private static var assignmentSelect: String {
        """
        id,
        assignment_date,
        word:words!daily_word_assignments_word_id_fkey(
            \(wordSelect)
        )
        """
    }

    static func makeLesson(
        assignmentID: UUID,
        assignmentDateKey: String,
        dayNumber: Int,
        word: WordWithRelationsDTO,
        progress: UserWordProgressDTO?,
        fallbackDate: Date = .now
    ) -> DailyLesson {
        DailyLesson(
            id: assignmentID,
            assignmentDate: SupabaseFieldParser.sqlDate(from: assignmentDateKey) ?? fallbackDate,
            dayNumber: dayNumber,
            languageName: word.languageName,
            word: word.toModel(),
            isLearned: progress.map(Self.isLearned(progress:)) ?? false,
            isFavorited: progress?.is_favorited ?? false,
            isSavedForReview: progress?.is_saved_for_review ?? false
        )
    }

    static func makeWordProgressState(progress: UserWordProgressDTO?) -> WordProgressState {
        WordProgressState(
            status: progress?.status ?? .new,
            isLearned: progress.map(Self.isLearned(progress:)) ?? false,
            isFavorited: progress?.is_favorited ?? false,
            isSavedForReview: progress?.is_saved_for_review ?? false
        )
    }

    static func mergeProgress(
        userID: UUID,
        wordID: UUID,
        existing: UserWordProgressDTO?,
        isLearned: Bool?,
        isFavorited: Bool?,
        isSavedForReview: Bool?,
        now: Date = .now
    ) -> UserWordProgressUpsertDTO {
        let mergedFavorited = isFavorited ?? existing?.is_favorited ?? false
        let mergedSavedForReview = isSavedForReview ?? existing?.is_saved_for_review ?? false
        let existingLearned = existing.map(isLearned(progress:)) ?? false
        let mergedLearned = isLearned ?? existingLearned

        let resolvedStatus: WordStatus
        if existing?.status == .mastered, isLearned == nil, !mergedSavedForReview {
            resolvedStatus = .mastered
        } else if mergedSavedForReview {
            resolvedStatus = .reviewDue
        } else if mergedLearned {
            resolvedStatus = existing?.status == .mastered ? .mastered : .learned
        } else {
            resolvedStatus = .new
        }

        return UserWordProgressUpsertDTO(
            user_id: userID,
            word_id: wordID,
            status: resolvedStatus,
            is_favorited: mergedFavorited,
            is_saved_for_review: mergedSavedForReview,
            consecutive_correct: existing?.consecutive_correct ?? 0,
            total_reviews: existing?.total_reviews ?? 0,
            correct_reviews: existing?.correct_reviews ?? 0,
            current_interval_days: existing?.current_interval_days ?? 0,
            next_review_at: mergedSavedForReview ? (existing?.next_review_at ?? now) : nil,
            learned_at: mergedLearned ? (existing?.learned_at ?? now) : nil,
            last_reviewed_at: existing?.last_reviewed_at
        )
    }

    private static func isLearned(progress: UserWordProgressDTO) -> Bool {
        progress.status != .new
    }

    private static func makeRelatedWords(
        from words: [WordWithRelationsDTO],
        referenceWordID: UUID,
        partOfSpeech: String?,
        cefrLevel: String?,
        frequencyRank: Int,
        limit: Int
    ) -> [WordWithRelationsDTO] {
        words
            .filter { $0.id != referenceWordID }
            .sorted { lhs, rhs in
                let lhsSamePart = normalized(lhs.part_of_speech) == normalized(partOfSpeech)
                let rhsSamePart = normalized(rhs.part_of_speech) == normalized(partOfSpeech)
                if lhsSamePart != rhsSamePart {
                    return lhsSamePart && !rhsSamePart
                }

                let lhsSameLevel = normalized(lhs.cefr_level) == normalized(cefrLevel)
                let rhsSameLevel = normalized(rhs.cefr_level) == normalized(cefrLevel)
                if lhsSameLevel != rhsSameLevel {
                    return lhsSameLevel && !rhsSameLevel
                }

                let lhsDistance = abs((lhs.frequency_rank ?? .max) - frequencyRank)
                let rhsDistance = abs((rhs.frequency_rank ?? .max) - frequencyRank)
                if lhsDistance != rhsDistance {
                    return lhsDistance < rhsDistance
                }

                return lhs.lemma.localizedCaseInsensitiveCompare(rhs.lemma) == .orderedAscending
            }
            .prefix(limit)
            .map { $0 }
    }

    private static func normalized(_ value: String?) -> String {
        value?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? ""
    }
}

private struct DailyWordAssignmentInsertDTO: Encodable {
    let user_id: UUID
    let word_id: UUID
    let assignment_date: String
    let source = "algorithm_v1"
}

struct UserWordProgressUpsertDTO: Encodable {
    let user_id: UUID
    let word_id: UUID
    let status: WordStatus
    let is_favorited: Bool
    let is_saved_for_review: Bool
    let consecutive_correct: Int
    let total_reviews: Int
    let correct_reviews: Int
    let current_interval_days: Int
    let next_review_at: Date?
    let learned_at: Date?
    let last_reviewed_at: Date?
}
