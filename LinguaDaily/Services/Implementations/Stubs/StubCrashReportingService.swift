import Foundation

final class StubCrashReportingService: CrashReportingServiceProtocol {
    func capture(_ error: Error, context: [String : String]) {
        #if DEBUG
        print("[Crash] \(error.localizedDescription) context=\(context)")
        #endif
    }
}
