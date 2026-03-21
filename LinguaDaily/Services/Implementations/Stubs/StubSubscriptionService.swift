import Foundation

final class StubSubscriptionService: SubscriptionServiceProtocol {
    private var state = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)

    func fetchSubscriptionState() async throws -> SubscriptionState {
        state
    }

    func purchaseMonthly() async throws -> SubscriptionState {
        state = SubscriptionState(tier: .premium, isTrial: true, expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now))
        return state
    }

    func purchaseYearly() async throws -> SubscriptionState {
        state = SubscriptionState(tier: .premium, isTrial: true, expiresAt: Calendar.current.date(byAdding: .day, value: 7, to: .now))
        return state
    }

    func restorePurchases() async throws -> SubscriptionState {
        state
    }
}
