import SwiftUI

struct SplashView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dependencies: AppDependencyContainer
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: LDSpacing.lg) {
            Spacer()
            Text("LinguaDaily")
                .font(LDTypography.hero())
                .foregroundStyle(LDColor.inkPrimary)
            Text("One useful word a day")
                .font(LDTypography.body())
                .foregroundStyle(LDColor.inkSecondary)
            if isLoading {
                ProgressView()
                    .padding(.top, LDSpacing.sm)
            }
            Spacer()
        }
        .padding(LDSpacing.xl)
        .task {
            await bootstrap()
        }
    }

    private func bootstrap() async {
        dependencies.analyticsService.track(.appOpened, properties: [:])
        defer {
            isLoading = false
            appState.isBootstrapping = false
        }

        do {
            appState.session = try await dependencies.authService.restoreSession()
            appState.onboardingState = try dependencies.onboardingService.loadOnboardingState()
            appState.subscriptionState = try await dependencies.subscriptionService.fetchSubscriptionState()

            if appState.session != nil {
                dependencies.analyticsService.track(.sessionRestored, properties: [:])
            }
        } catch {
            appState.session = nil
            appState.onboardingState = .empty
            appState.subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return SplashView()
        .environmentObject(dependencies.appState)
        .environmentObject(dependencies)
}
