import Foundation

protocol DailyLessonServiceProtocol {
    func fetchTodayLesson() async throws -> DailyLesson
    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws
    func fetchWordDetail(wordID: UUID) async throws -> Word
    func fetchWordProgressState(wordID: UUID) async throws -> WordProgressState
    func fetchRelatedWords(wordID: UUID, limit: Int) async throws -> [Word]
}
