import XCTest
@testable import LinguaDaily

@MainActor
final class ReviewViewModelTests: XCTestCase {
    func testLoadSuccessSetsCurrentCardAndProgressLabel() async {
        let reviewService = TestReviewService()
        reviewService.queue = [
            TestData.reviewCard(),
            TestData.reviewCard(
                id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
                selectedOptionID: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
                otherOptionID: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                lemma: "merci"
            )
        ]
        let analytics = TestAnalyticsService()
        let viewModel = ReviewViewModel(reviewService: reviewService, analytics: analytics, crash: TestCrashReportingService())

        await viewModel.load()

        XCTAssertEqual(viewModel.currentCard?.lemma, "bonjour")
        XCTAssertEqual(viewModel.progress.total, 2)
        XCTAssertEqual(viewModel.progress.remaining, 2)
        XCTAssertEqual(viewModel.progressLabel, "1 of 2")
        XCTAssertEqual(analytics.events.map(\.event), [.reviewOpened, .reviewStarted])
    }

    func testSubmitStoresFeedbackAndRecordsSelection() async {
        let reviewService = TestReviewService()
        let card = TestData.reviewCard()
        reviewService.queue = [card]
        let viewModel = ReviewViewModel(reviewService: reviewService, analytics: TestAnalyticsService(), crash: TestCrashReportingService())
        await viewModel.load()
        viewModel.selectOption(card.options[0].id)

        await viewModel.submit()

        XCTAssertEqual(reviewService.submittedAnswers.count, 1)
        XCTAssertEqual(reviewService.submittedAnswers.first?.cardID, card.id)
        XCTAssertEqual(reviewService.submittedAnswers.first?.selectedOptionID, card.options[0].id)
        XCTAssertEqual(viewModel.feedback, TestData.feedback())
    }

    func testNextAdvancesAndEmptiesAfterLastCard() async {
        let reviewService = TestReviewService()
        reviewService.queue = [TestData.reviewCard()]
        let analytics = TestAnalyticsService()
        let viewModel = ReviewViewModel(reviewService: reviewService, analytics: analytics, crash: TestCrashReportingService())
        await viewModel.load()
        viewModel.feedback = TestData.feedback()
        viewModel.selectedOptionID = reviewService.queue[0].options[0].id

        viewModel.next()

        XCTAssertNil(viewModel.feedback)
        XCTAssertNil(viewModel.selectedOptionID)
        XCTAssertEqual(viewModel.currentIndex, 1)
        guard case .empty = viewModel.phase else {
            return XCTFail("Expected empty phase")
        }
        XCTAssertEqual(analytics.events.map(\.event), [.reviewOpened, .reviewStarted, .reviewCompleted])
    }
}
