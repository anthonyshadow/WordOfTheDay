import Foundation
import Sentry

final class SentryCrashReportingService: CrashReportingServiceProtocol {
    private static let lock = NSLock()
    private static var configuredSignature: String?
    private static let redactedPlaceholder = "[REDACTED]"
    private static let sensitiveKeyFragments = [
        "token",
        "password",
        "secret",
        "authorization",
        "cookie",
        "api_key",
        "apikey"
    ]

    private let isConfigured: Bool

    init(
        dsn: String?,
        bundle: Bundle = .main,
        processInfo: ProcessInfo = .processInfo
    ) {
        if let dsn = Self.normalizedDSN(dsn),
           processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] != "1" {
            Self.configureIfNeeded(dsn: dsn, bundle: bundle)
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

    func setUser(_ session: AuthSession?) {
        guard isConfigured else {
            #if DEBUG
            if let session {
                print("[Crash] setUser \(session.userID.uuidString)")
            } else {
                print("[Crash] clearUser")
            }
            #endif
            return
        }

        guard let session else {
            SentrySDK.setUser(nil)
            return
        }

        let user = User(userId: session.userID.uuidString)
        user.email = session.email
        SentrySDK.setUser(user)
    }

    private static func configureIfNeeded(dsn: String, bundle: Bundle) {
        lock.lock()
        defer { lock.unlock() }

        let releaseName = releaseName(from: bundle)
        let environment = currentEnvironment
        let signature = "\(dsn)|\(releaseName ?? "")|\(environment)"
        guard configuredSignature != signature else {
            return
        }

        SentrySDK.start { options in
            options.dsn = dsn
            options.debug = _isDebugAssertConfiguration()
            options.releaseName = releaseName
            options.environment = environment
            options.beforeSend = { event in
                if let extra = event.extra {
                    event.extra = redactSensitiveProperties(in: extra)
                }
                if let context = event.context {
                    event.context = redactSensitiveContext(in: context)
                }
                return event
            }
        }
        configuredSignature = signature
    }

    private static var currentEnvironment: String {
        #if DEBUG
        return "debug"
        #else
        return "release"
        #endif
    }

    private static func releaseName(from bundle: Bundle) -> String? {
        guard let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
              !version.isEmpty else {
            return nil
        }

        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        let appIdentifier = bundle.bundleIdentifier ?? "LinguaDaily"
        if let build, !build.isEmpty {
            return "\(appIdentifier)@\(version)+\(build)"
        }
        return "\(appIdentifier)@\(version)"
    }

    static func normalizedDSN(_ dsn: String?) -> String? {
        guard var rawValue = dsn?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        if rawValue.hasPrefix("\""), rawValue.hasSuffix("\""), rawValue.count >= 2 {
            rawValue.removeFirst()
            rawValue.removeLast()
        }

        guard !rawValue.hasPrefix("YOUR_"),
              let url = URL(string: rawValue),
              url.scheme != nil,
              url.host != nil,
              rawValue.contains("@") else {
            return nil
        }

        return rawValue
    }

    private static func redactSensitiveProperties(in properties: [String: Any]) -> [String: Any] {
        properties.reduce(into: [String: Any]()) { result, entry in
            result[entry.key] = redact(entry.value, forKey: entry.key)
        }
    }

    private static func redactSensitiveContext(in context: [String: [String: Any]]) -> [String: [String: Any]] {
        context.reduce(into: [String: [String: Any]]()) { result, entry in
            result[entry.key] = redactSensitiveProperties(in: entry.value)
        }
    }

    private static func redact(_ value: Any, forKey key: String) -> Any {
        if isSensitive(key: key) {
            return redactedPlaceholder
        }

        if let nested = value as? [String: Any] {
            return redactSensitiveProperties(in: nested)
        }

        if let array = value as? [Any] {
            return array.map { element -> Any in
                if let nested = element as? [String: Any] {
                    return redactSensitiveProperties(in: nested)
                }
                return element
            }
        }

        return value
    }

    private static func isSensitive(key: String) -> Bool {
        let normalized = key.lowercased()
        return sensitiveKeyFragments.contains { normalized.contains($0) }
    }
}
