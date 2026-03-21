import Foundation

enum EntitlementTier: String, Codable, Hashable {
    case free
    case premium
}

struct SubscriptionState: Codable, Hashable {
    var tier: EntitlementTier
    var isTrial: Bool
    var expiresAt: Date?
}
