import Foundation

struct ReviewScheduler {
    private let intervals: [Int] = [1, 3, 7, 14, 30]

    func schedule(
        previousIntervalDays: Int,
        consecutiveCorrect: Int,
        totalReviews: Int,
        wasCorrect: Bool,
        referenceDate: Date = .now
    ) -> (nextIntervalDays: Int, nextReviewAt: Date, nextConsecutiveCorrect: Int, nextStatus: WordStatus) {
        if wasCorrect {
            let nextConsecutive = consecutiveCorrect + 1
            let stageIndex = min(max(stageIndex(for: previousIntervalDays) + 1, 0), intervals.count - 1)
            let nextInterval = intervals[stageIndex]
            let nextDate = Calendar.current.date(byAdding: .day, value: nextInterval, to: referenceDate) ?? referenceDate
            let mastered = nextConsecutive >= 4 && (totalReviews + 1) >= 5
            return (nextInterval, nextDate, nextConsecutive, mastered ? .mastered : .learned)
        }

        let nextDate = Calendar.current.date(byAdding: .day, value: intervals[0], to: referenceDate) ?? referenceDate
        return (intervals[0], nextDate, 0, .reviewDue)
    }

    private func stageIndex(for interval: Int) -> Int {
        guard let index = intervals.firstIndex(of: interval) else {
            return 0
        }
        return index
    }
}
