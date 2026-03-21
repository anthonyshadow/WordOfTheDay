import Foundation
import Sentry

final class SentryCrashReportingService: CrashReportingServiceProtocol {
    private static let lock = NSLock()
    private static var configuredDSN: String?

    private let isConfigured: Bool

    init(dsn: String?) {
        if let dsn, !dsn.isEmpty {
            Self.configureIfNeeded(dsn: dsn)
            self.isConfigured = true
        } else {
            self.isConfigured = false
        }
    }

    func capture(_ error: Error, context: [String : String]) {
        guard isConfigured else {
            #if DEBUG
            print("[Crash] \(error.localizedDescription) context=\(context)")
            #endif
            return
        }

        let sentryContext = context.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value
        }

        SentrySDK.capture(error: error) { scope in
            scope.setContext(value: sentryContext, key: "app_context")
            if let feature = context["feature"] {
                scope.setTag(value: feature, key: "feature")
            }
        }
    }

    private static func configureIfNeeded(dsn: String) {
        lock.lock()
        defer { lock.unlock() }

        guard configuredDSN != dsn else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = _isDebugAssertConfiguration()
        }
        configuredDSN = dsn
    }
}
