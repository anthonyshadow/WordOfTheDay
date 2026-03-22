import Foundation

final class StubCrashReportingService: CrashReportingServiceProtocol {
    func capture(_ error: Error, context: [String : String]) {
        #if DEBUG
        print("[Crash] \(error.localizedDescription) context=\(context)")
        #endif
    }

    func setUser(_ session: AuthSession?) {
        #if DEBUG
        if let session {
            print("[Crash] setUser \(session.userID.uuidString)")
        } else {
            print("[Crash] clearUser")
        }
        #endif
    }
}
