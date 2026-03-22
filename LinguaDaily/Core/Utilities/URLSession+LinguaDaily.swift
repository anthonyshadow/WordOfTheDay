import Foundation

extension URLSession {
    static func linguaDailyExternalAPISession(timeout: TimeInterval = 5) -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = timeout
        configuration.timeoutIntervalForResource = timeout
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }
}
