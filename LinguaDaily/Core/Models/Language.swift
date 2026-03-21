import Foundation

struct Language: Identifiable, Codable, Hashable {
    let id: UUID
    let code: String
    let name: String
    let nativeName: String
    let isActive: Bool
}
