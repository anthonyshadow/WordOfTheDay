import Foundation
import PostHog

final class PostHogAnalyticsService: AnalyticsServiceProtocol {
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

    init(apiKey: String?, host: String?) {
        if let apiKey, !apiKey.isEmpty {
            Self.configureIfNeeded(apiKey: apiKey, host: host)
            self.isConfigured = true
        } else {
            self.isConfigured = false
        }
    }

    func track(_ event: AnalyticsEvent, properties: [String : String]) {
        guard isConfigured else {
            #if DEBUG
            print("[Analytics] \(event.rawValue) \(properties)")
            #endif
            return
        }

        let postHogProperties = properties.reduce(into: [String: Any]()) { partialResult, entry in
            partialResult[entry.key] = entry.value
        }
        PostHogSDK.shared.capture(event.rawValue, properties: postHogProperties)
    }

    func identify(_ session: AuthSession) {
        guard isConfigured else {
            #if DEBUG
            print("[Analytics] identify \(session.userID.uuidString)")
            #endif
            return
        }

        PostHogSDK.shared.identify(
            session.userID.uuidString,
            userProperties: ["email": session.email]
        )
    }

    func reset() {
        guard isConfigured else {
            #if DEBUG
            print("[Analytics] reset")
            #endif
            return
        }

        PostHogSDK.shared.reset()
    }

    private static func configureIfNeeded(apiKey: String, host: String?) {
        lock.lock()
        defer { lock.unlock() }

        let sanitizedHost = host?.trimmingCharacters(in: .whitespacesAndNewlines)
        let signature = "\(apiKey)|\(sanitizedHost ?? "")"
        guard configuredSignature != signature else {
            return
        }

        let config: PostHogConfig
        if let sanitizedHost, !sanitizedHost.isEmpty {
            config = PostHogConfig(apiKey: apiKey, host: sanitizedHost)
        } else {
            config = PostHogConfig(apiKey: apiKey)
        }
        // We already emit curated lifecycle and screen events manually in the app.
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.debug = _isDebugAssertConfiguration()
        config.setBeforeSend { event in
            event.properties = redactSensitiveProperties(in: event.properties)
            return event
        }
        PostHogSDK.shared.setup(config)
        configuredSignature = signature
    }

    private static func redactSensitiveProperties(in properties: [String: Any]) -> [String: Any] {
        properties.reduce(into: [String: Any]()) { result, entry in
            result[entry.key] = redact(entry.value, forKey: entry.key)
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
