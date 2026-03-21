import Foundation

final class PostHogAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent, properties: [String : String]) {
        // Replace with PostHog SDK capture call when API key/project is configured.
        #if DEBUG
        print("[PostHog pending] \(event.rawValue) \(properties)")
        #endif
    }
}
