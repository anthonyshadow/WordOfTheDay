import Foundation

struct APIRequest {
    let path: String
    let method: String
    let queryItems: [URLQueryItem]
    let headers: [String: String]
    let body: Data?

    init(path: String, method: String = "GET", queryItems: [URLQueryItem] = [], headers: [String: String] = [:], body: Data? = nil) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

protocol APIClientProtocol {
    func send<T: Decodable>(_ request: APIRequest) async throws -> T
}

final class APIClient: APIClientProtocol {
    private let baseURL: URL
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(baseURL: URL, session: URLSession = .shared) {
        self.baseURL = baseURL
        self.session = session
        decoder.dateDecodingStrategy = .iso8601
    }

    func send<T: Decodable>(_ request: APIRequest) async throws -> T {
        var components = URLComponents(url: baseURL.appending(path: request.path), resolvingAgainstBaseURL: false)
        components?.queryItems = request.queryItems.isEmpty ? nil : request.queryItems

        guard let url = components?.url else {
            throw AppError.network("Invalid URL")
        }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        request.headers.forEach { key, value in
            urlRequest.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: urlRequest)
        guard let httpResponse = response as? HTTPURLResponse, (200...299).contains(httpResponse.statusCode) else {
            throw AppError.network("Request failed")
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw AppError.decoding("Could not decode response")
        }
    }
}
