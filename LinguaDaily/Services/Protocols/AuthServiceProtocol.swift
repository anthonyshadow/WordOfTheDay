import Foundation

struct AuthSession: Codable, Hashable {
    let userID: UUID
    let email: String
    let authToken: String
}

protocol AuthServiceProtocol {
    func restoreSession() async throws -> AuthSession?
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(email: String, password: String, displayName: String?) async throws -> AuthSession
    func signInWithApple() async throws -> AuthSession
    func signInWithGoogle() async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
}
