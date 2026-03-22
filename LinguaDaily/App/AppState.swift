import Foundation
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var session: AuthSession?
    @Published var onboardingState: OnboardingState = .empty
    @Published var selectedTab: MainTab = .today
    @Published var path: [AppDestination] = []
    @Published var subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
    @Published var appearancePreference: AppearancePreference = .system
    @Published var isBootstrapping = true

    var isAuthenticated: Bool { session != nil }
    var hasCompletedOnboarding: Bool { onboardingState.isCompleted }

    func handleDeepLink(_ target: DeepLinkTarget) {
        switch target {
        case .today:
            selectedTab = .today
        case .review:
            selectedTab = .review
        }
    }

    func resetNavigation() {
        path.removeAll()
    }

    func resetForSignedOutUser() {
        session = nil
        onboardingState = .empty
        selectedTab = .today
        subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
        appearancePreference = .system
        resetNavigation()
    }
}
