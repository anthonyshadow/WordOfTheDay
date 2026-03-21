import Foundation

protocol AnalyticsServiceProtocol {
    func track(_ event: AnalyticsEvent, properties: [String: String])
}
