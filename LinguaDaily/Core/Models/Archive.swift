import Foundation

enum ArchiveFilter: String, CaseIterable, Hashable {
    case all
    case learned
    case reviewDue = "review_due"
    case mastered
    case favorites

    var title: String {
        switch self {
        case .all: return "All"
        case .learned: return "Learned"
        case .reviewDue: return "Review due"
        case .mastered: return "Mastered"
        case .favorites: return "Favorites"
        }
    }
}

enum ArchiveSort: String, CaseIterable, Hashable {
    case newest
    case oldest
    case alphabetical
    case reviewDueSoon = "review_due_soon"

    var title: String {
        switch self {
        case .newest: return "Newest"
        case .oldest: return "Oldest"
        case .alphabetical: return "A-Z"
        case .reviewDueSoon: return "Review soon"
        }
    }
}

struct ArchiveWord: Identifiable, Codable, Hashable {
    let id: UUID
    let word: Word
    let status: WordStatus
    let dayNumber: Int
    let isFavorited: Bool
    let nextReviewAt: Date?
    let learnedAt: Date?
}
