import XCTest
@testable import LinguaDaily

@MainActor
final class PaywallViewModelTests: XCTestCase {
    func testBuyMonthlyCancellationRestoresExistingSubscriptionStateWithoutCrash() async {
        let subscriptionService = TestSubscriptionService()
        subscriptionService.monthlyResult = .failure(CancellationError())
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        appState.subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
        let viewModel = makeViewModel(
            subscriptionService: subscriptionService,
            analytics: analytics,
            crash: crash,
            appState: appState
        )

        await viewModel.buyMonthly()

        guard case let .success(state) = viewModel.phase else {
            return XCTFail("Expected success phase after cancellation")
        }
        XCTAssertEqual(state, appState.subscriptionState)
        XCTAssertTrue(crash.capturedErrors.isEmpty)
        XCTAssertFalse(analytics.events.map(\.event).contains(.purchaseFailed))
    }

    func testLoadStoresFetchedSubscriptionState() async {
        let subscriptionService = TestSubscriptionService()
        let expected = SubscriptionState(tier: .premium, isTrial: false, expiresAt: Date(timeIntervalSince1970: 1_800_000_000))
        subscriptionService.fetchResult = .success(expected)
        let appState = AppState()
        let viewModel = makeViewModel(subscriptionService: subscriptionService, appState: appState)

        await viewModel.load()

        guard case let .success(state) = viewModel.phase else {
            return XCTFail("Expected success phase")
        }
        XCTAssertEqual(state, expected)
        XCTAssertEqual(appState.subscriptionState, expected)
    }

    private func makeViewModel(
        subscriptionService: TestSubscriptionService = TestSubscriptionService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> PaywallViewModel {
        PaywallViewModel(
            subscriptionService: subscriptionService,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState()
        )
    }
}
