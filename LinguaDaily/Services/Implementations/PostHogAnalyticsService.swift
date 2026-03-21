import Foundation
import PostHog

final class PostHogAnalyticsService: AnalyticsServiceProtocol {
    private static let lock = NSLock()
    private static var configuredKey: String?

    private let isConfigured: Bool

    init(apiKey: String?) {
        if let apiKey, !apiKey.isEmpty {
            Self.configureIfNeeded(apiKey: apiKey)
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

    private static func configureIfNeeded(apiKey: String) {
        lock.lock()
        defer { lock.unlock() }

        guard configuredKey != apiKey else {
            return
        }

        let config = PostHogConfig(apiKey: apiKey)
        config.captureApplicationLifecycleEvents = false
        config.captureScreenViews = false
        config.debug = _isDebugAssertConfiguration()
        PostHogSDK.shared.setup(config)
        configuredKey = apiKey
    }
}
