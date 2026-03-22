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
    let pushRegistrationService: PushRegistrationServiceProtocol
    let subscriptionService: SubscriptionServiceProtocol
    let analyticsService: AnalyticsServiceProtocol
    let crashService: CrashReportingServiceProtocol
    let audioPlayerService: AudioPlayerServiceProtocol
    let translationService: TranslationServiceProtocol

    private let modelContainer: ModelContainer?

    init(
        modelContext: ModelContext,
        modelContainer: ModelContainer? = nil,
        environment: AppEnvironment = .load(),
        keyValueStore: LocalKeyValueStore = UserDefaultsStore(),
        testingMode: Bool = false
    ) {
        self.modelContainer = modelContainer
        self.environment = environment
        let appState = AppState()
        self.appState = appState

        let cacheStore: LocalCacheStore
        if let modelContainer {
            cacheStore = LocalCacheStore(modelContainer: modelContainer)
        } else {
            cacheStore = LocalCacheStore(modelContext: modelContext)
        }
        self.cacheStore = cacheStore

        if testingMode {
            let notificationService = StubNotificationService()
            self.subscriptionService = StubSubscriptionService()
            self.analyticsService = StubAnalyticsService()
            self.crashService = StubCrashReportingService()
            self.audioPlayerService = StubAudioPlayerService()
            self.authService = StubAuthService()
            self.onboardingService = StubOnboardingService(store: keyValueStore)
            self.dailyLessonService = StubDailyLessonService()
            self.reviewService = StubReviewService()
            self.archiveService = StubArchiveService()
            self.progressService = StubProgressService()
            self.notificationService = notificationService
            self.pushRegistrationService = notificationService
            self.translationService = StubTranslationService()
            return
        }

        let sessionProvider: @MainActor @Sendable () -> AuthSession? = { [weak appState] in
            appState?.session
        }
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

        if let supabaseConfig = environment.supabaseConfig {
            let wordCatalogPersistence = SupabaseWordCatalogPersistenceService(
                config: supabaseConfig,
                analytics: analyticsService,
                crash: crashService
            )
            let enrichmentCoordinator = WordEnrichmentCoordinator(
                wiktionaryClient: WiktionaryAPIClient(),
                forvoClient: ForvoAPIClient(apiKey: environment.forvoAPIKey),
                googleTextToSpeechClient: GoogleTextToSpeechClient(
                    apiKey: environment.googleTextToSpeechAPIKey,
                    preferredVoiceName: environment.googleTextToSpeechVoiceName
                ),
                cacheStore: cacheStore,
                persistenceService: wordCatalogPersistence,
                analytics: analyticsService,
                crash: crashService
            )
            let notificationService = SupabaseNotificationService(config: supabaseConfig)
            self.authService = SupabaseAuthService(config: supabaseConfig)
            self.onboardingService = SupabaseOnboardingService(config: supabaseConfig, store: keyValueStore)
            self.dailyLessonService = SupabaseDailyLessonService(
                config: supabaseConfig,
                cacheStore: cacheStore,
                enrichmentCoordinator: enrichmentCoordinator
            )
            self.reviewService = SupabaseReviewService(config: supabaseConfig)
            self.archiveService = SupabaseArchiveService(config: supabaseConfig)
            self.progressService = SupabaseProgressService(config: supabaseConfig)
            self.notificationService = notificationService
            self.pushRegistrationService = notificationService
            self.translationService = SupabaseTranslationService(config: supabaseConfig)
        } else {
            let notificationService = StubNotificationService()
            self.authService = StubAuthService()
            self.onboardingService = StubOnboardingService(store: keyValueStore)
            self.dailyLessonService = StubDailyLessonService()
            self.reviewService = StubReviewService()
            self.archiveService = StubArchiveService()
            self.progressService = StubProgressService()
            self.notificationService = notificationService
            self.pushRegistrationService = notificationService
            self.translationService = StubTranslationService()
        }

        if let savedOnboarding = try? onboardingService.loadOnboardingState() {
            appState.onboardingState = savedOnboarding
        }
    }
}
