import Foundation

protocol LocalKeyValueStore {
    func set<T: Codable>(_ value: T, for key: String) throws
    func get<T: Codable>(_ type: T.Type, for key: String) throws -> T?
}

final class UserDefaultsStore: LocalKeyValueStore {
    private let defaults: UserDefaults
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func set<T>(_ value: T, for key: String) throws where T: Codable {
        defaults.set(try encoder.encode(value), forKey: key)
    }

    func get<T>(_ type: T.Type, for key: String) throws -> T? where T: Codable {
        guard let data = defaults.data(forKey: key) else {
            return nil
        }
        return try decoder.decode(T.self, from: data)
    }
}
