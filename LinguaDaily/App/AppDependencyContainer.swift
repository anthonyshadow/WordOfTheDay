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

    init(modelContext: ModelContext) {
        self.environment = .load()
        self.appState = AppState()

        let keyValueStore = UserDefaultsStore()
        let cacheStore = LocalCacheStore(modelContext: modelContext)
        self.cacheStore = cacheStore

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
        self.notificationService = StubNotificationService()
        self.subscriptionService = StubSubscriptionService()
        self.analyticsService = StubAnalyticsService()
        self.crashService = StubCrashReportingService()
        self.audioPlayerService = StubAudioPlayerService()

        if let savedOnboarding = try? onboardingService.loadOnboardingState() {
            appState.onboardingState = savedOnboarding
        }
    }
}
