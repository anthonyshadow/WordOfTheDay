import Foundation

final class RevenueCatSubscriptionService: SubscriptionServiceProtocol {
    func fetchSubscriptionState() async throws -> SubscriptionState {
        // Replace with RevenueCat customer info mapping once SDK keys are configured.
        throw AppError.unknown("RevenueCat is not configured yet.")
    }

    func purchaseMonthly() async throws -> SubscriptionState {
        throw AppError.unknown("RevenueCat monthly purchase is not configured yet.")
    }

    func purchaseYearly() async throws -> SubscriptionState {
        throw AppError.unknown("RevenueCat yearly purchase is not configured yet.")
    }

    func restorePurchases() async throws -> SubscriptionState {
        throw AppError.unknown("RevenueCat restore is not configured yet.")
    }
}
