import Foundation

final class StubPushRegistrationService: PushRegistrationServiceProtocol {
    func registerDeviceToken(_ tokenData: Data) async throws {
        #if DEBUG
        print("[Push] token bytes=\(tokenData.count)")
        #endif
    }
}
