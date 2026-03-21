import Foundation
import Supabase

final class SupabaseArchiveService: ArchiveServiceProtocol {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchArchive(filter: ArchiveFilter, sort: ArchiveSort, query: String) async throws -> [ArchiveWord] {
        let userID = try await currentUserID()

        async let assignmentsTask = fetchAssignments(userID: userID)
        async let progressTask = fetchProgress(userID: userID)

        let archiveWords = Self.makeArchiveWords(
            assignments: try await assignmentsTask,
            progress: try await progressTask,
            referenceDate: Date()
        )

        return Self.filterAndSortArchive(
            words: archiveWords,
            filter: filter,
            sort: sort,
            query: query
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

    private func fetchAssignments(userID: UUID) async throws -> [DailyWordAssignmentWithWordDTO] {
        do {
            return try await client
                .from("daily_word_assignments")
                .select(Self.assignmentSelect)
                .eq("user_id", value: userID)
                .order("assignment_date", ascending: true)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func fetchProgress(userID: UUID) async throws -> [UserWordProgressDTO] {
        do {
            return try await client
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
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? "Could not load your archive." : message)
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

    static func makeArchiveWords(
        assignments: [DailyWordAssignmentWithWordDTO],
        progress: [UserWordProgressDTO],
        referenceDate: Date = .now
    ) -> [ArchiveWord] {
        let progressByWordID = Dictionary(uniqueKeysWithValues: progress.map { ($0.word_id, $0) })
        let sortedAssignments = assignments.sorted { lhs, rhs in
            if lhs.assignment_date != rhs.assignment_date {
                return lhs.assignment_date < rhs.assignment_date
            }
            return lhs.word.lemma.localizedCaseInsensitiveCompare(rhs.word.lemma) == .orderedAscending
        }

        return sortedAssignments.enumerated().map { index, assignment in
            let progress = progressByWordID[assignment.word.id]
            return ArchiveWord(
                id: assignment.id,
                word: assignment.word.toModel(),
                status: resolvedArchiveStatus(progress: progress, referenceDate: referenceDate),
                dayNumber: index + 1,
                isFavorited: progress?.is_favorited ?? false,
                nextReviewAt: progress?.next_review_at,
                learnedAt: progress?.learned_at
            )
        }
    }

    static func filterAndSortArchive(
        words: [ArchiveWord],
        filter: ArchiveFilter,
        sort: ArchiveSort,
        query: String
    ) -> [ArchiveWord] {
        let filteredByStatus = words.filter { word in
            switch filter {
            case .all:
                return true
            case .learned:
                return word.status == .learned
            case .reviewDue:
                return word.status == .reviewDue
            case .mastered:
                return word.status == .mastered
            case .favorites:
                return word.isFavorited
            }
        }

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        let searchedWords: [ArchiveWord]
        if trimmedQuery.isEmpty {
            searchedWords = filteredByStatus
        } else {
            searchedWords = filteredByStatus.filter {
                $0.word.lemma.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.word.definition.localizedCaseInsensitiveContains(trimmedQuery)
                || $0.word.examples.contains(where: { $0.sentence.localizedCaseInsensitiveContains(trimmedQuery) })
            }
        }

        switch sort {
        case .newest:
            return searchedWords.sorted(by: { $0.dayNumber > $1.dayNumber })
        case .oldest:
            return searchedWords.sorted(by: { $0.dayNumber < $1.dayNumber })
        case .alphabetical:
            return searchedWords.sorted(by: {
                $0.word.lemma.localizedCaseInsensitiveCompare($1.word.lemma) == .orderedAscending
            })
        case .reviewDueSoon:
            return searchedWords.sorted(by: {
                ($0.nextReviewAt ?? .distantFuture) < ($1.nextReviewAt ?? .distantFuture)
            })
        }
    }

    static func resolvedArchiveStatus(progress: UserWordProgressDTO?, referenceDate: Date = .now) -> WordStatus {
        guard let progress else {
            return .new
        }

        if progress.status == .mastered {
            return .mastered
        }

        if progress.is_saved_for_review,
           let nextReviewAt = progress.next_review_at,
           nextReviewAt <= referenceDate {
            return .reviewDue
        }

        if progress.status == .reviewDue {
            return .reviewDue
        }

        if progress.learned_at != nil || progress.status == .learned {
            return .learned
        }

        return progress.status
    }
}
