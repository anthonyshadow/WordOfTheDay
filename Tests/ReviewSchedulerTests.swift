import XCTest
@testable import LinguaDaily

final class ReviewSchedulerTests: XCTestCase {
    func testCorrectAnswerAdvancesInterval() {
        let scheduler = ReviewScheduler()
        let result = scheduler.schedule(
            previousIntervalDays: 1,
            consecutiveCorrect: 1,
            totalReviews: 2,
            wasCorrect: true,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(result.nextIntervalDays, 3)
        XCTAssertEqual(result.nextStatus, .learned)
    }

    func testIncorrectAnswerResetsInterval() {
        let scheduler = ReviewScheduler()
        let result = scheduler.schedule(
            previousIntervalDays: 14,
            consecutiveCorrect: 4,
            totalReviews: 8,
            wasCorrect: false,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(result.nextIntervalDays, 1)
        XCTAssertEqual(result.nextConsecutiveCorrect, 0)
        XCTAssertEqual(result.nextStatus, .reviewDue)
    }

    func testMasteryAfterThreshold() {
        let scheduler = ReviewScheduler()
        let result = scheduler.schedule(
            previousIntervalDays: 7,
            consecutiveCorrect: 3,
            totalReviews: 4,
            wasCorrect: true,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(result.nextStatus, .mastered)
    }
}
