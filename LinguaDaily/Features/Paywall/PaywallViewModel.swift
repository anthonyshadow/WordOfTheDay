import Foundation
import Combine

@MainActor
final class PaywallViewModel: ObservableObject {
    @Published var phase: AsyncPhase<SubscriptionState> = .idle

    private let subscriptionService: SubscriptionServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState

    init(
        subscriptionService: SubscriptionServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crash: CrashReportingServiceProtocol,
        appState: AppState
    ) {
        self.subscriptionService = subscriptionService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
    }

    func load() async {
        phase = .loading
        do {
            let state = try await subscriptionService.fetchSubscriptionState()
            appState.subscriptionState = state
            phase = .success(state)
            analytics.track(.paywallOpened, properties: ["tier": state.tier.rawValue])
            analytics.track(.paywallViewed, properties: ["tier": state.tier.rawValue])
        } catch {
            crash.capture(error, context: ["feature": "paywall_load"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func buyMonthly() async {
        analytics.track(.paywallPlanSelected, properties: ["plan": "monthly"])
        analytics.track(.subscriptionStarted, properties: ["plan": "monthly"])
        await purchase { try await subscriptionService.purchaseMonthly() }
    }

    func buyYearly() async {
        analytics.track(.paywallPlanSelected, properties: ["plan": "yearly"])
        analytics.track(.subscriptionStarted, properties: ["plan": "yearly"])
        await purchase { try await subscriptionService.purchaseYearly() }
    }

    func restore() async {
        analytics.track(.restorePurchasesTapped, properties: [:])
        await purchase { try await subscriptionService.restorePurchases() }
    }

    private func purchase(_ operation: () async throws -> SubscriptionState) async {
        phase = .loading
        analytics.track(.purchaseStarted, properties: [:])
        do {
            let state = try await operation()
            appState.subscriptionState = state
            phase = .success(state)
            analytics.track(.purchaseSuccess, properties: ["tier": state.tier.rawValue])
        } catch {
            crash.capture(error, context: ["feature": "purchase"])
            analytics.track(.purchaseFailed, properties: [:])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }
}
