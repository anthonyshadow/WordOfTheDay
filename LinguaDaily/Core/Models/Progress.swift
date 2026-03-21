import Foundation

struct ProgressSnapshot: Codable, Hashable {
    let currentStreakDays: Int
    let bestStreakDays: Int
    let wordsLearned: Int
    let masteredCount: Int
    let reviewAccuracy: Double
    let weeklyActivity: [WeeklyActivityPoint]
    let bestRetentionCategory: String
}

struct WeeklyActivityPoint: Identifiable, Codable, Hashable {
    let id: UUID
    let weekdayLabel: String
    let score: Int
}
