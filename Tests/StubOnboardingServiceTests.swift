import XCTest
@testable import LinguaDaily

final class StubOnboardingServiceTests: XCTestCase {
    func testFetchAvailableLanguagesIncludesAllSeededLanguageCodes() async throws {
        let defaults = UserDefaults(suiteName: "StubOnboardingServiceTests.\(UUID().uuidString)")!
        let service = StubOnboardingService(store: UserDefaultsStore(defaults: defaults))

        let languages = try await service.fetchAvailableLanguages()

        XCTAssertEqual(languages.map(\.code), ["fr", "de", "es", "it", "ja", "ko", "zh"])
    }
}
