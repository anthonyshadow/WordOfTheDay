import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var isSignup = false
    @Published var phase: AsyncPhase<Void> = .idle

    private let authService: AuthServiceProtocol
    private let analytics: AnalyticsServiceProtocol
    private let crash: CrashReportingServiceProtocol
    private let appState: AppState

    init(authService: AuthServiceProtocol, analytics: AnalyticsServiceProtocol, crash: CrashReportingServiceProtocol, appState: AppState) {
        self.authService = authService
        self.analytics = analytics
        self.crash = crash
        self.appState = appState
    }

    func onAppear() {
        analytics.track(.authViewOpened, properties: ["mode": isSignup ? "signup" : "login"])
    }

    var isValid: Bool {
        email.contains("@") && password.count >= 6
    }

    func submitEmail() async {
        phase = .loading
        do {
            let session: AuthSession
            if isSignup {
                analytics.track(.authEmailSignupTapped, properties: [:])
                session = try await authService.signUp(email: email, password: password)
            } else {
                analytics.track(.authEmailLoginTapped, properties: [:])
                session = try await authService.signIn(email: email, password: password)
            }
            appState.session = session
            phase = .success(())
            analytics.track(.authSuccess, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "auth_email"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func signInWithApple() async {
        phase = .loading
        do {
            analytics.track(.authAppleTapped, properties: [:])
            appState.session = try await authService.signInWithApple()
            phase = .success(())
            analytics.track(.authSuccess, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "auth_apple"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }

    func signInWithGoogle() async {
        phase = .loading
        do {
            analytics.track(.authGoogleTapped, properties: [:])
            appState.session = try await authService.signInWithGoogle()
            phase = .success(())
            analytics.track(.authSuccess, properties: [:])
        } catch {
            crash.capture(error, context: ["feature": "auth_google"])
            phase = .failure((error as? AppError)?.viewError ?? .generic)
        }
    }
}
