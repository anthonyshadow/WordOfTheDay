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
            let restoredSession = try await dependencies.authService.restoreSession()
            let persistedOnboardingState = try dependencies.onboardingService.loadOnboardingState()

            appState.session = restoredSession
            if restoredSession == nil && persistedOnboardingState.isCompleted {
                try? dependencies.onboardingService.saveOnboardingState(.empty)
                appState.onboardingState = .empty
            } else {
                appState.onboardingState = persistedOnboardingState
            }
        } catch {
            appState.resetForSignedOutUser()
        }
        dependencies.crashService.setUser(appState.session)

        do {
            appState.subscriptionState = try await dependencies.subscriptionService.fetchSubscriptionState()
        } catch {
            appState.subscriptionState = SubscriptionState(tier: .free, isTrial: false, expiresAt: nil)
            dependencies.crashService.capture(error, context: ["feature": "bootstrap_subscription"])
        }

        if appState.session != nil {
            if let session = appState.session {
                dependencies.analyticsService.identify(session)
            }
            await hydrateOnboardingStateIfNeeded()
            dependencies.analyticsService.track(.sessionRestored, properties: [:])
        }
    }

    private func hydrateOnboardingStateIfNeeded() async {
        if appState.onboardingState.isCompleted {
            try? await dependencies.onboardingService.syncAuthenticatedState(appState.onboardingState)
            if let profile = try? await dependencies.progressService.fetchProfile() {
                appState.appearancePreference = profile.appearancePreference
            }
            return
        }

        guard let profile = try? await dependencies.progressService.fetchProfile(),
              profile.activeLanguage != nil else {
            return
        }

        appState.appearancePreference = profile.appearancePreference
        let restoredState = OnboardingState.completed(from: profile)
        do {
            try dependencies.onboardingService.saveOnboardingState(restoredState)
            appState.onboardingState = restoredState
        } catch {
            dependencies.crashService.capture(error, context: ["feature": "bootstrap_onboarding_restore"])
        }
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return SplashView()
        .environmentObject(dependencies.appState)
        .environmentObject(dependencies)
}
