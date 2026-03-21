import Foundation

protocol SubscriptionServiceProtocol {
    func fetchSubscriptionState() async throws -> SubscriptionState
    func purchaseMonthly() async throws -> SubscriptionState
    func purchaseYearly() async throws -> SubscriptionState
    func restorePurchases() async throws -> SubscriptionState
}
