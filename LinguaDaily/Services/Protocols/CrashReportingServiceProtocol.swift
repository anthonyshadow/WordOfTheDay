import Foundation

protocol CrashReportingServiceProtocol {
    func capture(_ error: Error, context: [String: String])
}
