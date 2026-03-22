import XCTest
@testable import LinguaDaily

@MainActor
final class AppStateTests: XCTestCase {
    func testIsAuthenticatedReflectsSessionPresence() {
        let appState = AppState()

        XCTAssertFalse(appState.isAuthenticated)

        appState.session = TestData.session()

        XCTAssertTrue(appState.isAuthenticated)
    }

    func testHasCompletedOnboardingReflectsState() {
        let appState = AppState()

        XCTAssertFalse(appState.hasCompletedOnboarding)

        appState.onboardingState.isCompleted = true

        XCTAssertTrue(appState.hasCompletedOnboarding)
    }

    func testHandleDeepLinkSelectsReviewTab() {
        let appState = AppState()
        appState.selectedTab = .today

        appState.handleDeepLink(.review)

        XCTAssertEqual(appState.selectedTab, .review)
    }

    func testResetNavigationClearsPath() {
        let appState = AppState()
        appState.path = [.settings, .paywall]

        appState.resetNavigation()

        XCTAssertTrue(appState.path.isEmpty)
    }

    func testResetForSignedOutUserClearsSessionOnboardingSubscriptionAndNavigation() {
        let appState = AppState()
        appState.session = TestData.session()
        appState.onboardingState = OnboardingState.completed(from: SampleData.profile)
        appState.subscriptionState = SubscriptionState(tier: .premium, isTrial: false, expiresAt: nil)
        appState.selectedTab = .profile
        appState.path = [.settings, .paywall]

        appState.resetForSignedOutUser()

        XCTAssertNil(appState.session)
        XCTAssertEqual(appState.onboardingState, .empty)
        XCTAssertEqual(appState.subscriptionState.tier, .free)
        XCTAssertEqual(appState.selectedTab, .today)
        XCTAssertTrue(appState.path.isEmpty)
    }
}
