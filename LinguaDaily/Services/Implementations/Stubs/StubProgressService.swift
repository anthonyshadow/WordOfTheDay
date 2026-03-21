import Foundation

final class StubProgressService: ProgressServiceProtocol {
    func fetchProgress() async throws -> ProgressSnapshot {
        SampleData.progress
    }

    func fetchProfile() async throws -> UserProfile {
        SampleData.profile
    }
}
