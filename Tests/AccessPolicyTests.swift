import XCTest
@testable import LinguaDaily

final class AccessPolicyTests: XCTestCase {
    func testFreeTierAppliesLimit() {
        let words = Array(repeating: SampleData.archive, count: 4).flatMap { $0 }
        let limited = AccessPolicy.applyArchiveLimit(words: words, tier: .free)

        XCTAssertEqual(limited.count, AccessPolicy.freeArchiveLimit)
    }

    func testFreeTierKeepsAllWordsWhenUnderLimit() {
        let words = Array(SampleData.archive.prefix(5))

        let limited = AccessPolicy.applyArchiveLimit(words: words, tier: .free)

        XCTAssertEqual(limited, words)
    }

    func testPremiumTierNoLimit() {
        let words = Array(repeating: SampleData.archive, count: 4).flatMap { $0 }
        let full = AccessPolicy.applyArchiveLimit(words: words, tier: .premium)

        XCTAssertEqual(full.count, words.count)
    }
}
