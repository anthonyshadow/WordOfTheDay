import XCTest
@testable import LinguaDaily

final class SentryCrashReportingServiceTests: XCTestCase {
    func testNormalizedDSNAcceptsQuotedValidValue() {
        let dsn = "\"https://examplePublicKey@o123456.ingest.us.sentry.io/7890\""

        let normalized = SentryCrashReportingService.normalizedDSN(dsn)

        XCTAssertEqual(
            normalized,
            "https://examplePublicKey@o123456.ingest.us.sentry.io/7890"
        )
    }

    func testNormalizedDSNRejectsPlaceholderAndMalformedValues() {
        XCTAssertNil(SentryCrashReportingService.normalizedDSN("\"YOUR_SENTRY_DSN\""))
        XCTAssertNil(SentryCrashReportingService.normalizedDSN("not-a-dsn"))
        XCTAssertNil(SentryCrashReportingService.normalizedDSN("https://ingest.us.sentry.io/7890"))
        XCTAssertNil(SentryCrashReportingService.normalizedDSN(nil))
    }
}
