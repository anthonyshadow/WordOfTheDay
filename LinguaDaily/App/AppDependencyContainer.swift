import Foundation
import Combine
import SwiftData

@MainActor
final class AppDependencyContainer: ObservableObject {
    let environment: AppEnvironment
    let appState: AppState
    let cacheStore: LocalCacheStore

    let authService: AuthServiceProtocol
    let onboardingService: OnboardingServiceProtocol
    let dailyLessonService: DailyLessonServiceProtocol
    let reviewService: ReviewServiceProtocol
    let archiveService: ArchiveServiceProtocol
    let progressService: ProgressServiceProtocol
    let notificationService: NotificationServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let crashService: CrashReportingServiceProtocol
    let audioPlayerService: AudioPlayerServiceProtocol

    init(
        modelContext: ModelContext,
        environment: AppEnvironment = .load(),
        keyValueStore: LocalKeyValueStore = UserDefaultsStore()
    ) {
        self.environment = environment
        let appState = AppState()
        self.appState = appState

        let cacheStore = LocalCacheStore(modelContext: modelContext)
        self.cacheStore = cacheStore
        let sessionProvider: @MainActor @Sendable () -> AuthSession? = { [weak appState] in
            appState?.session
        }

        if let supabaseConfig = environment.supabaseConfig {
            self.authService = SupabaseAuthService(config: supabaseConfig)
            self.onboardingService = SupabaseOnboardingService(config: supabaseConfig, store: keyValueStore)
            self.dailyLessonService = SupabaseDailyLessonService(config: supabaseConfig)
            self.reviewService = SupabaseReviewService(config: supabaseConfig)
            self.archiveService = SupabaseArchiveService(config: supabaseConfig)
            self.progressService = SupabaseProgressService(config: supabaseConfig)
        } else {
            self.authService = StubAuthService()
            self.onboardingService = StubOnboardingService(store: keyValueStore)
            self.dailyLessonService = StubDailyLessonService()
            self.reviewService = StubReviewService()
            self.archiveService = StubArchiveService()
            self.progressService = StubProgressService()
        }
        self.notificationService = LocalNotificationService(store: keyValueStore)
        self.subscriptionService = RevenueCatSubscriptionService(
            apiKey: environment.revenueCatKey,
            sessionProvider: sessionProvider
        )
        self.analyticsService = PostHogAnalyticsService(
            apiKey: environment.posthogKey,
            host: environment.posthogHost
        )
        self.crashService = SentryCrashReportingService(dsn: environment.sentryDSN)
        self.audioPlayerService = SystemAudioPlayerService()

        if let savedOnboarding = try? onboardingService.loadOnboardingState() {
            appState.onboardingState = savedOnboarding
        }
    }
}
