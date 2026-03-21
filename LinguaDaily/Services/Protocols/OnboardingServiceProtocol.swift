import Foundation

protocol OnboardingServiceProtocol {
    func loadOnboardingState() throws -> OnboardingState
    func saveOnboardingState(_ state: OnboardingState) throws
}
