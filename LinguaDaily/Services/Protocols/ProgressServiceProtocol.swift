import Foundation

protocol ProgressServiceProtocol {
    func fetchProgress() async throws -> ProgressSnapshot
    func fetchProfile() async throws -> UserProfile
    func updateProfile(_ request: UserProfileUpdateRequest) async throws -> UserProfile
    func fetchAvailableAccents(languageID: UUID?) async throws -> [String]
}
