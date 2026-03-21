import Foundation

final class StubAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        #if DEBUG
        print("[Analytics] \(event.rawValue) \(properties)")
        #endif
    }
}
