import Foundation

enum WordStatus: String, Codable, CaseIterable, Hashable {
    case new
    case learned
    case reviewDue = "review_due"
    case mastered

    var title: String {
        switch self {
        case .new:
            return "New"
        case .learned:
            return "Learned"
        case .reviewDue:
            return "Review due"
        case .mastered:
            return "Mastered"
        }
    }
}

struct ReviewOption: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let isCorrect: Bool
}

struct ReviewCard: Identifiable, Codable, Hashable {
    let id: UUID
    let wordID: UUID
    let lemma: String
    let pronunciation: String
    let options: [ReviewOption]
    let correctMeaning: String
}

struct ReviewFeedback: Codable, Hashable {
    let isCorrect: Bool
    let explanation: String
    let nextReviewDate: Date
}

struct ReviewProgressSnapshot: Codable, Hashable {
    let total: Int
    let remaining: Int
    let correct: Int
    let incorrect: Int
}
