import Foundation
import Combine

@MainActor
final class ReviewViewModel: ObservableObject {
    @Published var phase: AsyncPhase<[ReviewCard]> = .idle
    @Published var currentIndex = 0
    @Published var feedback: ReviewFeedback?
    @Published var selectedOptionID: UUID?

    private let reviewService: ReviewServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol

    init(reviewService: ReviewServiceProtocol, analytics: AnalyticsServiceProtocol, crash: CrashReportingServiceProtocol) {
        self.reviewService = reviewService
        self.analytics = analytics
        self.crash = crash
    }

    var currentCard: ReviewCard? {
        guard case let .success(cards) = phase, cards.indices.contains(currentIndex) else {
            return nil
        }
        return cards[currentIndex]
    }

    var progress: ReviewProgressSnapshot {
        guard case let .success(cards) = phase else {
            return ReviewProgressSnapshot(total: 0, remaining: 0, correct: 0, incorrect: 0)
        }
        return ReviewProgressSnapshot(total: cards.count, remaining: max(0, cards.count - currentIndex), correct: 0, incorrect: 0)
    }

    var progressLabel: String? {
        guard case let .success(cards) = phase, !cards.isEmpty else {
            return nil
        }
        let current = min(currentIndex + 1, cards.count)
        return "\(current) of \(cards.count)"
    }

    func load() async {
        phase = .loading
        do {
            let cards = try await reviewService.fetchReviewQueue()
            if cards.isEmpty {
                phase = .empty
                analytics.track(.reviewQueueEmpty, properties: [:])
            } else {
                phase = .success(cards)
                currentIndex = 0
                feedback = nil
                analytics.track(.reviewOpened, properties: ["count": "\(cards.count)"])
                analytics.track(.reviewStarted, properties: ["count": "\(cards.count)"])
            }
        } catch {
            crash.capture(error, context: ["feature": "review_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func selectOption(_ optionID: UUID) {
        selectedOptionID = optionID
    }

    func submit() async {
        guard let card = currentCard, let selectedOptionID else {
            return
        }
        do {
            analytics.track(.reviewAnswerSubmitted, properties: ["word": card.lemma])
            let result = try await reviewService.submitAnswer(cardID: card.id, selectedOptionID: selectedOptionID)
            feedback = result
            analytics.track(result.isCorrect ? .reviewAnswerCorrect : .reviewAnswerIncorrect, properties: ["word": card.lemma])
        } catch {
            crash.capture(error, context: ["feature": "review_submit"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func next() {
        feedback = nil
        selectedOptionID = nil
        currentIndex += 1

        guard case let .success(cards) = phase else {
            return
        }
        if currentIndex >= cards.count {
            analytics.track(.reviewCompleted, properties: ["count": "\(cards.count)"])
            phase = .empty
        }
    }
}
