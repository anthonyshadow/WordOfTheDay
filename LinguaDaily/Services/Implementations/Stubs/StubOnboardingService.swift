import Foundation

final class StubOnboardingService: OnboardingServiceProtocol {
    private let store: LocalKeyValueStore
    private let key = "linguadaily.onboarding.state"
    private let sampleLanguages: [Language] = [
        SampleData.french,
        Language(id: UUID(), code: "es", name: "Spanish", nativeName: "Espanol", isActive: true),
        Language(id: UUID(), code: "ja", name: "Japanese", nativeName: "Nihongo", isActive: true),
        Language(id: UUID(), code: "it", name: "Italian", nativeName: "Italiano", isActive: true),
        Language(id: UUID(), code: "ko", name: "Korean", nativeName: "Hangukeo", isActive: true)
    ]

    init(store: LocalKeyValueStore) {
        self.store = store
    }

    func loadOnboardingState() throws -> OnboardingState {
        try store.get(OnboardingState.self, for: key) ?? .empty
    }

    func saveOnboardingState(_ state: OnboardingState) throws {
        try store.set(state, for: key)
    }

    func fetchAvailableLanguages() async throws -> [Language] {
        sampleLanguages
    }

    func syncAuthenticatedState(_ state: OnboardingState) async throws {}
}
