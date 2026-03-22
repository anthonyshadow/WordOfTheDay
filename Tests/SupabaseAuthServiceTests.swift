import XCTest
import Supabase
@testable import LinguaDaily

final class SupabaseAuthServiceTests: XCTestCase {
    func testRestoreSessionPassesThroughStoredSession() async throws {
        let client = MockSupabaseAuthClient()
        client.restoreSessionResult = .success(TestData.session(email: "restored@example.com"))
        let service = SupabaseAuthService(client: client)

        let session = try await service.restoreSession()

        XCTAssertEqual(session?.email, "restored@example.com")
    }

    func testSignInValidatesInputBeforeHittingClient() async {
        let client = MockSupabaseAuthClient()
        let service = SupabaseAuthService(client: client)

        do {
            _ = try await service.signIn(email: "bad", password: "123")
            XCTFail("Expected validation error")
        } catch let error as AppError {
            XCTAssertEqual(error, .validation("Use a valid email and password."))
            XCTAssertTrue(client.signInCalls.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testSignUpIncludesTimezoneAndDisplayNameMetadata() async throws {
        let client = MockSupabaseAuthClient()
        client.signUpResult = .success(TestData.session(email: "signup@example.com"))
        let service = SupabaseAuthService(client: client)

        let session = try await service.signUp(
            email: "signup@example.com",
            password: "secret1",
            displayName: "Taylor Example"
        )

        XCTAssertEqual(session.email, "signup@example.com")
        XCTAssertEqual(client.signUpCalls.count, 1)
        XCTAssertEqual(client.signUpCalls.first?.metadata["timezone"]?.stringValue, TimeZone.current.identifier)
        XCTAssertEqual(client.signUpCalls.first?.metadata["display_name"]?.stringValue, "Taylor Example")
        XCTAssertEqual(client.signUpCalls.first?.metadata["full_name"]?.stringValue, "Taylor Example")
        XCTAssertEqual(client.signUpCalls.first?.metadata["name"]?.stringValue, "Taylor Example")
    }

    func testSignInMapsUnderlyingErrorsToAppAuthError() async {
        let client = MockSupabaseAuthClient()
        client.signInResult = .failure(MockError(message: "Invalid login credentials"))
        let service = SupabaseAuthService(client: client)

        do {
            _ = try await service.signIn(email: "user@example.com", password: "secret1")
            XCTFail("Expected auth error")
        } catch let error as AppError {
            XCTAssertEqual(error, .auth("Invalid login credentials"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testThirdPartySignInMethodsExplainMissingConfiguration() async {
        let service = SupabaseAuthService(client: MockSupabaseAuthClient())

        do {
            _ = try await service.signInWithApple()
            XCTFail("Expected auth error")
        } catch let error as AppError {
            XCTAssertEqual(error, .auth("Sign in with Apple isn't configured yet."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            _ = try await service.signInWithGoogle()
            XCTFail("Expected auth error")
        } catch let error as AppError {
            XCTAssertEqual(error, .auth("Google sign-in isn't configured yet."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}

private final class MockSupabaseAuthClient: SupabaseAuthClientProtocol {
    private(set) var signInCalls: [(email: String, password: String)] = []
    private(set) var signUpCalls: [(email: String, password: String, metadata: [String: AnyJSON])] = []
    private(set) var signOutCallCount = 0

    var restoreSessionResult: Result<AuthSession?, Error> = .success(nil)
    var signInResult: Result<AuthSession, Error> = .success(TestData.session())
    var signUpResult: Result<AuthSession, Error> = .success(TestData.session(email: "signup@example.com"))
    var signOutError: Error?

    func restoreSession() async throws -> AuthSession? {
        try restoreSessionResult.get()
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        signInCalls.append((email, password))
        return try signInResult.get()
    }

    func signUp(email: String, password: String, metadata: [String : AnyJSON]) async throws -> AuthSession {
        signUpCalls.append((email, password, metadata))
        return try signUpResult.get()
    }

    func signOut() async throws {
        signOutCallCount += 1
        if let signOutError {
            throw signOutError
        }
    }
}

private struct MockError: LocalizedError {
    let message: String

    var errorDescription: String? { message }
}
