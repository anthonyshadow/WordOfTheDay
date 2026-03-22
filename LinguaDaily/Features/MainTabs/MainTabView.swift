import SwiftUI

struct MainTabView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var dependencies: AppDependencyContainer

    var body: some View {
        TabView(selection: $appState.selectedTab) {
            TodayView(
                viewModel: TodayViewModel(
                    lessonService: dependencies.dailyLessonService,
                    reviewService: dependencies.reviewService,
                    progressService: dependencies.progressService,
                    audioPlayer: dependencies.audioPlayerService,
                    cacheStore: dependencies.cacheStore,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService
                )
            )
            .tabItem { Label(MainTab.today.title, systemImage: MainTab.today.systemImage) }
            .tag(MainTab.today)

            TranslateView(
                viewModel: TranslateViewModel(
                    onboardingService: dependencies.onboardingService,
                    translationService: dependencies.translationService,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService,
                    appState: appState
                ),
                savedLibraryViewModel: SavedTranslationsViewModel(
                    translationService: dependencies.translationService,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService
                )
            )
            .tabItem { Label(MainTab.translate.title, systemImage: MainTab.translate.systemImage) }
            .tag(MainTab.translate)

            ReviewView(
                viewModel: ReviewViewModel(
                    reviewService: dependencies.reviewService,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService
                )
            )
            .tabItem { Label(MainTab.review.title, systemImage: MainTab.review.systemImage) }
            .tag(MainTab.review)

            ArchiveView(
                viewModel: ArchiveViewModel(
                    archiveService: dependencies.archiveService,
                    cacheStore: dependencies.cacheStore,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService,
                    entitlementProvider: { appState.subscriptionState.tier }
                )
            )
            .tabItem { Label(MainTab.words.title, systemImage: MainTab.words.systemImage) }
            .tag(MainTab.words)

            LearningProgressView(
                viewModel: ProgressViewModel(
                    progressService: dependencies.progressService,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService
                )
            )
            .tabItem { Label(MainTab.progress.title, systemImage: MainTab.progress.systemImage) }
            .tag(MainTab.progress)

            ProfileView(
                viewModel: ProfileViewModel(
                    progressService: dependencies.progressService,
                    onboardingService: dependencies.onboardingService,
                    analytics: dependencies.analyticsService,
                    crash: dependencies.crashService,
                    appState: appState
                )
            )
            .tabItem { Label(MainTab.profile.title, systemImage: MainTab.profile.systemImage) }
            .tag(MainTab.profile)
        }
        .tint(LDColor.accent)
        .toolbarBackground(LDColor.surface, for: .tabBar)
    }
}

#Preview {
    let dependencies = PreviewFactory.makeContainer()
    return MainTabView()
        .environmentObject(dependencies.appState)
        .environmentObject(dependencies)
}
