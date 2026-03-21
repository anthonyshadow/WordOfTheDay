import Foundation

protocol PushRegistrationServiceProtocol {
    func registerDeviceToken(_ tokenData: Data) async throws
}
