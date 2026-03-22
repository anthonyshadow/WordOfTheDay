import Foundation

final class StubAuthService: AuthServiceProtocol {
    private var currentSession: AuthSession?

    func restoreSession() async throws -> AuthSession? {
        currentSession
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard email.contains("@"), password.count >= 6 else {
            throw AppError.validation("Use a valid email and password.")
        }
        let session = AuthSession(userID: UUID(), email: email, authToken: UUID().uuidString)
        currentSession = session
        return session
    }

    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSession {
        try await signIn(email: email, password: password)
    }

    func signInWithApple() async throws -> AuthSession {
        let session = AuthSession(userID: UUID(), email: "appleuser@privaterelay.appleid.com", authToken: UUID().uuidString)
        currentSession = session
        return session
    }

    func signInWithGoogle() async throws -> AuthSession {
        let session = AuthSession(userID: UUID(), email: "googleuser@gmail.com", authToken: UUID().uuidString)
        currentSession = session
        return session
    }

    func signOut() async throws {
        currentSession = nil
    }

    func deleteAccount() async throws {
        currentSession = nil
    }
}
