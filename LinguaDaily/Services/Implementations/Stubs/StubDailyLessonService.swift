import Foundation

final class StubDailyLessonService: DailyLessonServiceProtocol {
    private var lesson = SampleData.todayLesson

    func fetchTodayLesson() async throws -> DailyLesson {
        lesson
    }

    func updateLessonState(wordID: UUID, isLearned: Bool?, isFavorited: Bool?, isSavedForReview: Bool?) async throws {
        guard lesson.word.id == wordID else { return }
        if let isLearned { lesson.isLearned = isLearned }
        if let isFavorited { lesson.isFavorited = isFavorited }
        if let isSavedForReview { lesson.isSavedForReview = isSavedForReview }
    }

    func fetchWordDetail(wordID: UUID) async throws -> Word {
        if lesson.word.id == wordID {
            return lesson.word
        }
        if let word = SampleData.words.first(where: { $0.id == wordID }) {
            return word
        }
        throw AppError.network("Word not found")
    }
}
