import Foundation
@testable import LinguaDaily

struct TrackedAnalyticsEvent: Equatable {
    let event: AnalyticsEvent
    let properties: [String: String]
}

final class TestAnalyticsService: AnalyticsServiceProtocol {
    private(set) var events: [TrackedAnalyticsEvent] = []
    private(set) var identifiedSessions: [AuthSession] = []
    private(set) var resetCallCount = 0

    func track(_ event: AnalyticsEvent, properties: [String : String]) {
        events.append(TrackedAnalyticsEvent(event: event, properties: properties))
    }

    func identify(_ session: AuthSession) {
        identifiedSessions.append(session)
    }

    func reset() {
        resetCallCount += 1
    }
}

final class TestCrashReportingService: CrashReportingServiceProtocol {
    private(set) var capturedErrors: [Error] = []
    private(set) var contexts: [[String: String]] = []
    private(set) var userSessions: [AuthSession?] = []

    func capture(_ error: Error, context: [String : String]) {
        capturedErrors.append(error)
        contexts.append(context)
    }

    func setUser(_ session: AuthSession?) {
        userSessions.append(session)
    }
}

final class TestSubscriptionService: SubscriptionServiceProtocol {
    var fetchResult: Result<SubscriptionState, Error> = .success(SubscriptionState(tier: .free, isTrial: false, expiresAt: nil))
    var monthlyResult: Result<SubscriptionState, Error> = .success(SubscriptionState(tier: .premium, isTrial: true, expiresAt: nil))
    var yearlyResult: Result<SubscriptionState, Error> = .success(SubscriptionState(tier: .premium, isTrial: true, expiresAt: nil))
    var restoreResult: Result<SubscriptionState, Error> = .success(SubscriptionState(tier: .free, isTrial: false, expiresAt: nil))

    private(set) var fetchCallCount = 0
    private(set) var purchaseMonthlyCallCount = 0
    private(set) var purchaseYearlyCallCount = 0
    private(set) var restoreCallCount = 0

    func fetchSubscriptionState() async throws -> SubscriptionState {
        fetchCallCount += 1
        return try fetchResult.get()
    }

    func purchaseMonthly() async throws -> SubscriptionState {
        purchaseMonthlyCallCount += 1
        return try monthlyResult.get()
    }

    func purchaseYearly() async throws -> SubscriptionState {
        purchaseYearlyCallCount += 1
        return try yearlyResult.get()
    }

    func restorePurchases() async throws -> SubscriptionState {
        restoreCallCount += 1
        return try restoreResult.get()
    }
}

final class TestAuthService: AuthServiceProtocol {
    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signUpCalls: [(email: String, password: String, displayName: String?)] = []
    private(set) var signOutCallCount = 0

    var restoreSessionResult: AuthSession?
    var signInResult: Result<AuthSession, Error> = .success(TestData.session())
    var signUpResult: Result<AuthSession, Error> = .success(TestData.session(email: "signup@example.com"))
    var appleResult: Result<AuthSession, Error> = .success(TestData.session(email: "apple@example.com"))
    var googleResult: Result<AuthSession, Error> = .success(TestData.session(email: "google@example.com"))
    var signOutError: Error?

    func restoreSession() async throws -> AuthSession? {
        restoreSessionResult
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        signInCalls.append((email, password))
        return try signInResult.get()
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSession {
        signUpCalls.append((email, password, displayName))
        return try signUpResult.get()
    }

    func signInWithApple() async throws -> AuthSession {
        try appleResult.get()
    }

    func signInWithGoogle() async throws -> AuthSession {
        try googleResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
    }
}

final class TestNotificationService: NotificationServiceProtocol {
    var authorizationResult = false
    var preference = NotificationPreference(
        isEnabled: false,
        reminderTime: Date(timeIntervalSince1970: 1_700_000_000),
        timezoneIdentifier: "UTC"
    )
    var loadError: Error?
    var updateError: Error?
    var scheduleError: Error?

    private(set) var updatedPreferences: [NotificationPreference] = []
    private(set) var scheduledPreferences: [NotificationPreference] = []

    func requestAuthorization() async -> Bool {
        authorizationResult
    }

    func loadPreference() async throws -> NotificationPreference {
        if let loadError {
            throw loadError
        }
        return preference
    }

    func updatePreference(_ preference: NotificationPreference) async throws {
        if let updateError {
            throw updateError
        }
        self.preference = preference
        updatedPreferences.append(preference)
    }

    func scheduleLocalReminder(preference: NotificationPreference) async throws {
        if let scheduleError {
            throw scheduleError
        }
        scheduledPreferences.append(preference)
    }
}

final class TestOnboardingService: OnboardingServiceProtocol {
    var storedState: OnboardingState = .empty
    var loadError: Error?
    var saveError: Error?
    var fetchAvailableLanguagesResult: Result<[Language], Error> = .success([SampleData.french])
    var syncError: Error?

    private(set) var savedStates: [OnboardingState] = []
    private(set) var syncedStates: [OnboardingState] = []
    private(set) var fetchAvailableLanguagesCallCount = 0

    func loadOnboardingState() throws -> OnboardingState {
        if let loadError {
            throw loadError
        }
        return storedState
    }

    func saveOnboardingState(_ state: OnboardingState) throws {
        if let saveError {
            throw saveError
        }
        storedState = state
        savedStates.append(state)
    }

    func fetchAvailableLanguages() async throws -> [Language] {
        fetchAvailableLanguagesCallCount += 1
        return try fetchAvailableLanguagesResult.get()
    }

    func syncAuthenticatedState(_ state: OnboardingState) async throws {
        syncedStates.append(state)
        if let syncError {
            throw syncError
        }
    }
}

final class TestProgressService: ProgressServiceProtocol {
    var progressResult: Result<ProgressSnapshot, Error> = .success(SampleData.progress)
    var profileResult: Result<UserProfile, Error> = .success(SampleData.profile)

    private(set) var fetchProgressCallCount = 0
    private(set) var fetchProfileCallCount = 0

    func fetchProgress() async throws -> ProgressSnapshot {
        fetchProgressCallCount += 1
        return try progressResult.get()
    }

    func fetchProfile() async throws -> UserProfile {
        fetchProfileCallCount += 1
        return try profileResult.get()
    }
}

final class TestReviewService: ReviewServiceProtocol {
    var queue: [ReviewCard] = []
    var fetchError: Error?
    var submitResult: Result<ReviewFeedback, Error> = .success(TestData.feedback())

    private(set) var submittedAnswers: [(cardID: UUID, selectedOptionID: UUID)] = []

    func fetchReviewQueue() async throws -> [ReviewCard] {
        if let fetchError {
            throw fetchError
        }
        return queue
    }

    func submitAnswer(cardID: UUID, selectedOptionID: UUID) async throws -> ReviewFeedback {
        submittedAnswers.append((cardID, selectedOptionID))
        return try submitResult.get()
    }
}

enum TestData {
    static func session(email: String = "tester@example.com") -> AuthSession {
        AuthSession(
            userID: UUID(uuidString: "AAAAAAAA-AAAA-AAAA-AAAA-AAAAAAAAAAAA")!,
            email: email,
            authToken: "token"
        )
    }

    static func feedback(isCorrect: Bool = true) -> ReviewFeedback {
        ReviewFeedback(
            isCorrect: isCorrect,
            explanation: isCorrect ? "Correct" : "Incorrect",
            nextReviewDate: Date(timeIntervalSince1970: 1_700_086_400)
        )
    }

    static func reviewCard(
        id: UUID = UUID(uuidString: "BBBBBBBB-BBBB-BBBB-BBBB-BBBBBBBBBBBB")!,
        selectedOptionID: UUID = UUID(uuidString: "CCCCCCCC-CCCC-CCCC-CCCC-CCCCCCCCCCCC")!,
        otherOptionID: UUID = UUID(uuidString: "DDDDDDDD-DDDD-DDDD-DDDD-DDDDDDDDDDDD")!,
        lemma: String = "bonjour"
    ) -> ReviewCard {
        ReviewCard(
            id: id,
            wordID: UUID(uuidString: "EEEEEEEE-EEEE-EEEE-EEEE-EEEEEEEEEEEE")!,
            lemma: lemma,
            pronunciation: "/bɔ̃.ʒuʁ/",
            options: [
                ReviewOption(id: selectedOptionID, text: "Hello", isCorrect: true),
                ReviewOption(id: otherOptionID, text: "Goodbye", isCorrect: false)
            ],
            correctMeaning: "Hello"
        )
    }
}
