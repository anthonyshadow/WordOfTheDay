import Foundation

final class StubAnalyticsService: AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent, properties: [String: String] = [:]) {
        #if DEBUG
        print("[Analytics] \(event.rawValue) \(properties)")
        #endif
    }

    func identify(_ session: AuthSession) {
        #if DEBUG
        print("[Analytics] identify \(session.userID.uuidString)")
        #endif
    }

    func reset() {
        #if DEBUG
        print("[Analytics] reset")
        #endif
    }
}
