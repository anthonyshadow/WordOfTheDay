import Foundation

struct DailyWordAssigner {
    func assignWord(
        allWords: [Word],
        alreadyAssignedWordIDs: Set<UUID>,
        today: Date = .now
    ) -> Word? {
        let available = allWords
            .filter { !alreadyAssignedWordIDs.contains($0.id) }
            .sorted(by: { $0.frequencyRank < $1.frequencyRank })

        if let first = available.first {
            return first
        }

        // v1 fallback: recycle lowest-frequency words when pool exhausted
        return allWords.sorted(by: { $0.frequencyRank < $1.frequencyRank }).first
    }
}
