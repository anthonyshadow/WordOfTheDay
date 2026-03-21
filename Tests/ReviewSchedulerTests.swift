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

    func testCorrectAnswerCapsAtMaximumInterval() {
        let scheduler = ReviewScheduler()

        let result = scheduler.schedule(
            previousIntervalDays: 30,
            consecutiveCorrect: 2,
            totalReviews: 7,
            wasCorrect: true,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(result.nextIntervalDays, 30)
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

    func testUnknownIntervalUsesFirstProgressionStage() {
        let scheduler = ReviewScheduler()

        let result = scheduler.schedule(
            previousIntervalDays: 99,
            consecutiveCorrect: 0,
            totalReviews: 0,
            wasCorrect: true,
            referenceDate: Date(timeIntervalSince1970: 0)
        )

        XCTAssertEqual(result.nextIntervalDays, 3)
        XCTAssertEqual(result.nextStatus, .learned)
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

    func testNextReviewDateMatchesComputedInterval() {
        let scheduler = ReviewScheduler()
        let referenceDate = Date(timeIntervalSince1970: 1_700_000_000)

        let result = scheduler.schedule(
            previousIntervalDays: 3,
            consecutiveCorrect: 2,
            totalReviews: 3,
            wasCorrect: true,
            referenceDate: referenceDate
        )

        let expectedDate = Calendar.current.date(byAdding: .day, value: 7, to: referenceDate)
        XCTAssertEqual(result.nextReviewAt, expectedDate)
    }
}
