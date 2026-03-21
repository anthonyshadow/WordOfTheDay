import Foundation

final class StubOnboardingService: OnboardingServiceProtocol {
    private let store: LocalKeyValueStore
    private let key = "linguadaily.onboarding.state"

    init(store: LocalKeyValueStore) {
        self.store = store
    }

    func loadOnboardingState() throws -> OnboardingState {
        try store.get(OnboardingState.self, for: key) ?? .empty
    }

    func saveOnboardingState(_ state: OnboardingState) throws {
        try store.set(state, for: key)
    }

    func syncAuthenticatedState(_ state: OnboardingState) async throws {}
}
