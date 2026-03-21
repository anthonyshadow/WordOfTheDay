import Foundation
import Combine

@MainActor
final class OnboardingViewModel: ObservableObject {
    enum Step: Int, CaseIterable {
        case welcome
        case goal
        case language
        case level
        case reminder
        case notifications
        case account

        var title: String {
            switch self {
            case .welcome: return "Learn a new word every day"
            case .goal: return "Why are you learning?"
            case .language: return "Pick your language"
            case .level: return "Choose your level"
            case .reminder: return "Daily reminder"
            case .notifications: return "Never miss today's word"
            case .account: return "Save your progress"
            }
        }

        var stepLabel: String {
            let visibleStepCount = 6
            let stepValue: Int
            switch self {
            case .welcome: stepValue = 1
            case .goal: stepValue = 2
            case .language: stepValue = 3
            case .level: stepValue = 4
            case .reminder: stepValue = 5
            case .notifications: stepValue = 6
            case .account: stepValue = 6
            }
            return "Step \(stepValue) of \(visibleStepCount)"
        }
    }

    @Published var step: Step = .welcome
    @Published var onboardingState: OnboardingState = .empty
    @Published var availableLanguages: [Language] = []
    @Published var languagePhase: AsyncPhase<[Language]> = .idle
    @Published var languageQuery = ""

    @Published var email = ""
    @Published var password = ""
    @Published var isCreatingAccount = true
    @Published var asyncPhase: AsyncPhase<Void> = .idle

    private let onboardingService: OnboardingServiceProtocol
    private let authService: AuthServiceProtocol
    private let notificationService: NotificationServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crashReporter: CrashReportingServiceProtocol
    private let appState: AppState

    init(
        onboardingService: OnboardingServiceProtocol,
        authService: AuthServiceProtocol,
        notificationService: NotificationServiceProtocol,
        analytics: AnalyticsServiceProtocol,
        crashReporter: CrashReportingServiceProtocol,
        appState: AppState
    ) {
        self.onboardingService = onboardingService
        self.authService = authService
        self.notificationService = notificationService
        self.analytics = analytics
        self.crashReporter = crashReporter
        self.appState = appState
        self.analytics.track(.onboardingStarted, properties: [:])

        do {
            onboardingState = try onboardingService.loadOnboardingState()
        } catch {
            onboardingState = .empty
        }
    }

    var canContinue: Bool {
        switch step {
        case .welcome:
            return true
        case .goal:
            return onboardingState.goal != nil
        case .language:
            return hasValidLanguageSelection
        case .level:
            return onboardingState.level != nil
        case .reminder:
            return onboardingState.reminderTime != nil
        case .notifications:
            return true
        case .account:
            return !email.isEmpty && password.count >= 6
        }
    }

    var filteredLanguages: [Language] {
        guard !languageQuery.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return availableLanguages
        }
        return availableLanguages.filter {
            $0.name.localizedCaseInsensitiveContains(languageQuery)
            || $0.nativeName.localizedCaseInsensitiveContains(languageQuery)
        }
    }

    func loadAvailableLanguagesIfNeeded() async {
        guard case .idle = languagePhase else {
            return
        }
        await reloadAvailableLanguages()
    }

    func retryLoadingLanguages() async {
        await reloadAvailableLanguages()
    }

    func continueTapped() {
        guard let next = Step(rawValue: step.rawValue + 1) else {
            return
        }
        step = next
    }

    func jumpToLoginFromWelcome() {
        isCreatingAccount = false
        step = .account
        analytics.track(.authViewOpened, properties: ["entry": "welcome_login"])
    }

    func backTapped() {
        guard let previous = Step(rawValue: step.rawValue - 1) else {
            return
        }
        step = previous
    }

    func updateGoal(_ goal: LearningGoal) {
        onboardingState.goal = goal
        persistState()
    }

    func updateLanguage(_ language: Language) {
        onboardingState.language = language
        persistState()
        analytics.track(.languageSelected, properties: ["language": language.code])
    }

    func updateLevel(_ level: LearningLevel) {
        onboardingState.level = level
        persistState()
    }

    func updateReminder(_ reminder: Date) {
        onboardingState.reminderTime = reminder
        persistState()
        analytics.track(.reminderTimeSet, properties: ["hour": "\(Calendar.current.component(.hour, from: reminder))"])
    }

    func requestNotifications() async {
        analytics.track(.notificationsPermissionRequested, properties: [:])
        let granted = await notificationService.requestAuthorization()
        onboardingState.hasRequestedNotificationPermission = true
        onboardingState.hasSeenNotificationEducation = true
        persistState()
        analytics.track(.notificationsPermissionResult, properties: ["granted": granted ? "true" : "false"])
        if granted {
            analytics.track(.notificationPermissionGranted, properties: [:])
        }
    }

    func trackNotificationEducationViewed() {
        analytics.track(.notificationsEducationViewed, properties: [:])
    }

    func skipNotifications() {
        onboardingState.hasSeenNotificationEducation = true
        persistState()
    }

    func submitEmailAuth() async {
        asyncPhase = .loading
        do {
            analytics.track(.authViewOpened, properties: ["mode": isCreatingAccount ? "signup" : "login"])
            let session: AuthSession
            if isCreatingAccount {
                analytics.track(.authEmailSignupTapped, properties: [:])
                session = try await authService.signUp(email: email, password: password)
            } else {
                analytics.track(.authEmailLoginTapped, properties: [:])
                session = try await authService.signIn(email: email, password: password)
            }
            await completeOnboarding(session: session)
        } catch {
            crashReporter.capture(error, context: ["feature": "onboarding_auth_email"])
            asyncPhase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func signInWithApple() async {
        asyncPhase = .loading
        do {
            analytics.track(.authAppleTapped, properties: [:])
            let session = try await authService.signInWithApple()
            await completeOnboarding(session: session)
        } catch {
            crashReporter.capture(error, context: ["feature": "onboarding_auth_apple"])
            asyncPhase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func signInWithGoogle() async {
        asyncPhase = .loading
        do {
            analytics.track(.authGoogleTapped, properties: [:])
            let session = try await authService.signInWithGoogle()
            await completeOnboarding(session: session)
        } catch {
            crashReporter.capture(error, context: ["feature": "onboarding_auth_google"])
            asyncPhase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    private func completeOnboarding(session: AuthSession) async {
        onboardingState.isCompleted = true
        persistState()
        do {
            try await onboardingService.syncAuthenticatedState(onboardingState)
        } catch {
            crashReporter.capture(error, context: ["feature": "onboarding_sync"])
        }
        appState.session = session
        appState.onboardingState = onboardingState
        analytics.identify(session)
        analytics.track(.authSuccess, properties: [:])
        analytics.track(.signupCompleted, properties: [:])
        analytics.track(.onboardingCompleted, properties: [
            "language": onboardingState.language?.code ?? "unknown",
            "goal": onboardingState.goal?.rawValue ?? "unknown"
        ])
        asyncPhase = .success(())
    }

    private var hasValidLanguageSelection: Bool {
        guard let selectedCode = onboardingState.language?.code.lowercased() else {
            return false
        }
        return availableLanguages.contains { $0.code.lowercased() == selectedCode }
    }

    private func reloadAvailableLanguages() async {
        languagePhase = .loading
        do {
            let languages = try await onboardingService.fetchAvailableLanguages()
            availableLanguages = languages
            reconcileSelectedLanguage(with: languages)
            languagePhase = languages.isEmpty ? .empty : .success(languages)
        } catch {
            availableLanguages = []
            crashReporter.capture(error, context: ["feature": "onboarding_languages"])
            languagePhase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    private func reconcileSelectedLanguage(with languages: [Language]) {
        guard let selectedCode = onboardingState.language?.code.lowercased() else {
            return
        }

        if let canonicalLanguage = languages.first(where: { $0.code.lowercased() == selectedCode }) {
            if onboardingState.language != canonicalLanguage {
                onboardingState.language = canonicalLanguage
                persistState()
            }
            return
        }

        onboardingState.language = nil
        persistState()
    }

    private func persistState() {
        do {
            try onboardingService.saveOnboardingState(onboardingState)
            appState.onboardingState = onboardingState
        } catch {
            crashReporter.capture(error, context: ["feature": "onboarding_persist"])
        }
    }
}
