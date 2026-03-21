import Foundation

final class StubReviewService: ReviewServiceProtocol {
    private let scheduler = ReviewScheduler()
    private var cards = SampleData.reviewCards

    func fetchReviewQueue() async throws -> [ReviewCard] {
        cards
    }

    func submitAnswer(cardID: UUID, selectedOptionID: UUID) async throws -> ReviewFeedback {
        guard let card = cards.first(where: { $0.id == cardID }) else {
            throw AppError.validation("Review card missing")
        }
        guard let selected = card.options.first(where: { $0.id == selectedOptionID }) else {
            throw AppError.validation("Selected option missing")
        }

        let schedule = scheduler.schedule(
            previousIntervalDays: 3,
            consecutiveCorrect: selected.isCorrect ? 2 : 1,
            totalReviews: 4,
            wasCorrect: selected.isCorrect,
            referenceDate: .now
        )

        return ReviewFeedback(
            isCorrect: selected.isCorrect,
            explanation: selected.isCorrect ? "Correct" : "Correct meaning: \(card.correctMeaning)",
            nextReviewDate: schedule.nextReviewAt
        )
    }
}
