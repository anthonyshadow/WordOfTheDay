import Foundation

protocol ProgressServiceProtocol {
    func fetchProgress() async throws -> ProgressSnapshot
    func fetchProfile() async throws -> UserProfile
}
