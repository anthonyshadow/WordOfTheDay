import Foundation

final class SupabaseReviewService: ReviewServiceProtocol {
    private let client: APIClientProtocol
    private let scheduler = ReviewScheduler()

    init(client: APIClientProtocol) {
        self.client = client
    }

    func fetchReviewQueue() async throws -> [ReviewCard] {
        // Intended endpoint example:
        // GET /rest/v1/review_queue?state=eq.queued&due_at=lte.<now>
        throw AppError.unknown("SupabaseReviewService is scaffolded but not wired yet.")
    }

    func submitAnswer(cardID: UUID, selectedOptionID: UUID) async throws -> ReviewFeedback {
        // Intended flow:
        // 1) fetch current progress for word
        // 2) evaluate correctness server-side or deterministic client-side
        // 3) call scheduler + persist progress and queue updates
        _ = scheduler.schedule(previousIntervalDays: 1, consecutiveCorrect: 0, totalReviews: 0, wasCorrect: true)
        throw AppError.unknown("SupabaseReviewService is scaffolded but not wired yet.")
    }
}
