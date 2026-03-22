import XCTest
@testable import LinguaDaily

@MainActor
final class AuthViewModelTests: XCTestCase {
    func testIsValidRequiresEmailAndMinimumPasswordLength() {
        let viewModel = makeViewModel()

        viewModel.email = "invalid"
        viewModel.password = "12345"
        XCTAssertFalse(viewModel.isValid)

        viewModel.email = "user@example.com"
        viewModel.password = "123456"
        XCTAssertTrue(viewModel.isValid)

        viewModel.isSignup = true
        XCTAssertFalse(viewModel.isValid)

        viewModel.fullName = "Taylor Example"
        XCTAssertTrue(viewModel.isValid)
    }

    func testOnAppearTracksCurrentMode() {
        let analytics = TestAnalyticsService()
        let viewModel = makeViewModel(analytics: analytics)
        viewModel.isSignup = true

        viewModel.onAppear()

        XCTAssertEqual(analytics.events, [
            TrackedAnalyticsEvent(event: .authViewOpened, properties: ["mode": "signup"])
        ])
    }

    func testSubmitEmailLoginSuccessSetsSessionAndTracksEvents() async {
        let auth = TestAuthService()
        let analytics = TestAnalyticsService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        let viewModel = makeViewModel(auth: auth, analytics: analytics, crash: crash, appState: appState)
        viewModel.email = "login@example.com"
        viewModel.password = "secret1"

        await viewModel.submitEmail()

        XCTAssertEqual(auth.signInCalls.count, 1)
        XCTAssertEqual(auth.signUpCalls.count, 0)
        XCTAssertEqual(appState.session?.email, TestData.session().email)
        XCTAssertEqual(crash.userSessions, [TestData.session()])
        XCTAssertEqual(analytics.identifiedSessions, [TestData.session()])
        XCTAssertSuccess(viewModel.phase)
        XCTAssertEqual(analytics.events.map(\.event), [.authEmailLoginTapped, .authSuccess])
    }

    func testSubmitEmailSignupUsesSignUpPath() async {
        let auth = TestAuthService()
        let appState = AppState()
        let viewModel = makeViewModel(auth: auth, appState: appState)
        viewModel.isSignup = true
        viewModel.fullName = "Taylor Example"
        viewModel.email = "signup@example.com"
        viewModel.password = "secret1"

        await viewModel.submitEmail()

        XCTAssertEqual(auth.signInCalls.count, 0)
        XCTAssertEqual(auth.signUpCalls.count, 1)
        XCTAssertEqual(auth.signUpCalls.first?.displayName, "Taylor Example")
        XCTAssertEqual(appState.session?.email, "signup@example.com")
        XCTAssertSuccess(viewModel.phase)
    }

    func testSubmitEmailFailureCapturesCrashAndMapsViewError() async {
        let auth = TestAuthService()
        let crash = TestCrashReportingService()
        let appState = AppState()
        auth.signInResult = .failure(AppError.validation("Use a valid email and password."))
        let viewModel = makeViewModel(auth: auth, crash: crash, appState: appState)
        viewModel.email = "bad"
        viewModel.password = "123"

        await viewModel.submitEmail()

        XCTAssertNil(appState.session)
        XCTAssertEqual(crash.contexts, [["feature": "auth_email"]])
        guard case let .failure(error) = viewModel.phase else {
            return XCTFail("Expected failure phase")
        }
        XCTAssertEqual(error.title, "Invalid input")
        XCTAssertEqual(error.message, "Use a valid email and password.")
        XCTAssertEqual(error.actionTitle, "Update")
    }

    private func makeViewModel(
        auth: TestAuthService = TestAuthService(),
        analytics: TestAnalyticsService = TestAnalyticsService(),
        crash: TestCrashReportingService = TestCrashReportingService(),
        appState: AppState? = nil
    ) -> AuthViewModel {
        AuthViewModel(
            authService: auth,
            analytics: analytics,
            crash: crash,
            appState: appState ?? AppState()
        )
    }

    private func XCTAssertSuccess(_ phase: AsyncPhase<Void>, file: StaticString = #filePath, line: UInt = #line) {
        guard case .success = phase else {
            return XCTFail("Expected success phase", file: file, line: line)
        }
    }
}
