import Foundation

final class SentryCrashReportingService: CrashReportingServiceProtocol {
    func capture(_ error: Error, context: [String : String]) {
        // Replace with Sentry SDK captureError once DSN is configured.
        #if DEBUG
        print("[Sentry pending] \(error.localizedDescription) context=\(context)")
        #endif
    }
}
