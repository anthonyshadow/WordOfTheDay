import Foundation

final class SupabaseDailyLessonService: DailyLessonServiceProtocol {
    private let client: APIClientProtocol
    private let authTokenProvider: () -> String?

    init(client: APIClientProtocol, authTokenProvider: @escaping () -> String?) {
        self.client = client
        self.authTokenProvider = authTokenProvider
    }

    func fetchTodayLesson() async throws -> DailyLesson {
        // Intended endpoint example:
        // GET /rest/v1/daily_word_assignments?assignment_date=eq.<today>&select=word:words(*,example_sentences(*),word_audio(*))
        throw AppError.unknown("SupabaseDailyLessonService is scaffolded but not wired yet.")
    }

    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws {
        // Intended endpoint example:
        // PATCH /rest/v1/user_word_progress?word_id=eq.<wordID>
        throw AppError.unknown("SupabaseDailyLessonService is scaffolded but not wired yet.")
    }

    func fetchWordDetail(wordID: UUID) async throws -> Word {
        // Intended endpoint example:
        // GET /rest/v1/words?id=eq.<wordID>&select=*,example_sentences(*),word_audio(*)
        throw AppError.unknown("SupabaseDailyLessonService is scaffolded but not wired yet.")
    }
}
