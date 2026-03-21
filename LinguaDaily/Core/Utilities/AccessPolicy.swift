import Foundation

struct AccessPolicy {
    static let freeArchiveLimit = 30

    static func applyArchiveLimit(words: [ArchiveWord], tier: EntitlementTier) -> [ArchiveWord] {
        switch tier {
        case .free:
            return Array(words.prefix(freeArchiveLimit))
        case .premium:
            return words
        }
    }
}
