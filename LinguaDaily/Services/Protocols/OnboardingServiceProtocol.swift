import Foundation

protocol OnboardingServiceProtocol {
    func loadOnboardingState() throws -> OnboardingState
    func saveOnboardingState(_ state: OnboardingState) throws
    func fetchAvailableLanguages() async throws -> [Language]
    func syncAuthenticatedState(_ state: OnboardingState) async throws
}
