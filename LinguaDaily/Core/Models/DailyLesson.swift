import Foundation

struct DailyLesson: Identifiable, Codable, Hashable {
    let id: UUID
    let assignmentDate: Date
    let dayNumber: Int
    let languageName: String
    let word: Word
    var isLearned: Bool
    var isFavorited: Bool
    var isSavedForReview: Bool
}
