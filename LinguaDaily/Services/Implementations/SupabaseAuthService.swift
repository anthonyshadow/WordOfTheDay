import Foundation
import Supabase

protocol SupabaseAuthClientProtocol {
    func restoreSession() async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String, metadata: [String: AnyJSON]) async throws -> AuthSession
    func signOut() async throws
}

final class SupabaseAuthService: AuthServiceProtocol {
    private let client: SupabaseAuthClientProtocol

    init(config: SupabaseConfig) {
        self.client = LiveSupabaseAuthClient(config: config)
    }

    init(client: SupabaseAuthClientProtocol) {
        self.client = client
    }

    func restoreSession() async throws -> AuthSession? {
        do {
            return try await client.restoreSession()
        } catch {
            throw normalize(error)
        }
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        try validate(email: email, password: password)

        do {
            return try await client.signIn(email: email, password: password)
        } catch {
            throw normalize(error)
        }
    }

    func signUp(email: String, password: String) async throws -> AuthSession {
        try validate(email: email, password: password)

        do {
            return try await client.signUp(
                email: email,
                password: password,
                metadata: signupMetadata()
            )
        } catch {
            throw normalize(error)
        }
    }

    func signInWithApple() async throws -> AuthSession {
        throw AppError.auth("Sign in with Apple isn't configured yet.")
    }

    func signInWithGoogle() async throws -> AuthSession {
        throw AppError.auth("Google sign-in isn't configured yet.")
    }

    func signOut() async throws {
        do {
            try await client.signOut()
        } catch {
            throw normalize(error)
        }
    }

    private func validate(email: String, password: String) throws {
        guard email.contains("@"), password.count >= 6 else {
            throw AppError.validation("Use a valid email and password.")
        }
    }

    private func signupMetadata() -> [String: AnyJSON] {
        ["timezone": .string(TimeZone.current.identifier)]
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.auth(message.isEmpty ? "Authentication failed." : message)
    }
}

private final class LiveSupabaseAuthClient: SupabaseAuthClientProtocol {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func restoreSession() async throws -> AuthSession? {
        guard client.auth.currentSession != nil else {
            return nil
        }

        let session = try await client.auth.session
        return try map(session: session)
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        let session = try await client.auth.signIn(email: email, password: password)
        return try map(session: session)
    }

    func signUp(email: String, password: String, metadata: [String : AnyJSON]) async throws -> AuthSession {
        let response = try await client.auth.signUp(
            email: email,
            password: password,
            data: metadata.isEmpty ? nil : metadata
        )

        guard let session = response.session else {
            throw AppError.auth("Check your email for a confirmation link, then log in.")
        }

        return try map(session: session)
    }

    func signOut() async throws {
        try await client.auth.signOut()
    }

    private func map(session: Session) throws -> AuthSession {
        guard let email = session.user.email else {
            throw AppError.auth("Supabase returned a session without an email address.")
        }

        return AuthSession(
            userID: session.user.id,
            email: email,
            authToken: session.accessToken
        )
    }
}
