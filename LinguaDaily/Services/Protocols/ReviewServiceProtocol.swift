import Foundation

protocol ReviewServiceProtocol {
    func fetchReviewQueue() async throws -> [ReviewCard]
    func submitAnswer(cardID: UUID, selectedOptionID: UUID) async throws -> ReviewFeedback
}
