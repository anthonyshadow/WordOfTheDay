import SwiftUI

struct RootView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dependencies: AppDependencyContainer

    var body: some View {
        NavigationStack(path: $appState.path) {
            Group {
                if appState.isBootstrapping {
                    SplashView()
                } else if !appState.hasCompletedOnboarding {
                    OnboardingFlowView(
                        viewModel: OnboardingViewModel(
                            onboardingService: dependencies.onboardingService,
                            authService: dependencies.authService,
                            notificationService: dependencies.notificationService,
                            analytics: dependencies.analyticsService,
                            crashReporter: dependencies.crashService,
                            appState: appState
                        )
                    )
                } else if !appState.isAuthenticated {
                    AuthView(
                        viewModel: AuthViewModel(
                            authService: dependencies.authService,
                            analytics: dependencies.analyticsService,
                            crash: dependencies.crashService,
                            appState: appState
                        )
                    )
                } else {
                    MainTabView()
                }
            }
            .navigationDestination(for: AppDestination.self) { destination in
                switch destination {
                case let .wordDetail(word):
                    WordDetailView(word: word)
                case .settings:
                    SettingsView(
                        viewModel: SettingsViewModel(
                            notificationService: dependencies.notificationService,
                            authService: dependencies.authService,
                            analytics: dependencies.analyticsService,
                            crash: dependencies.crashService,
                            appState: appState
                        )
                    )
                case .paywall:
                    PaywallView(
                        viewModel: PaywallViewModel(
                            subscriptionService: dependencies.subscriptionService,
                            analytics: dependencies.analyticsService,
                            crash: dependencies.crashService,
                            appState: appState
                        )
                    )
                }
            }
        }
        .background(LDColor.background.ignoresSafeArea())
    }
}
