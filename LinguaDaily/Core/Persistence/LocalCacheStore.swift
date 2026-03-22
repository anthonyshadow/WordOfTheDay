import Foundation
import SwiftData

@MainActor
protocol DailyLessonCaching {
    func saveDailyLesson(_ lesson: DailyLesson, for date: Date) throws
    func loadDailyLesson(for date: Date) throws -> DailyLesson?
}

@MainActor
final class LocalCacheStore: DailyLessonCaching {
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    func saveDailyLesson(_ lesson: DailyLesson, for date: Date = .now) throws {
        let key = Self.dateKey(from: date)
        let data = try encoder.encode(lesson)

        let descriptor = FetchDescriptor<CachedDailyLessonEntity>(
            predicate: #Predicate { $0.assignmentDateKey == key }
        )
        if let existing = try modelContext.fetch(descriptor).first {
            existing.payload = data
            existing.updatedAt = .now
        } else {
            let entity = CachedDailyLessonEntity(assignmentDateKey: key, payload: data)
            modelContext.insert(entity)
        }
        try modelContext.save()
    }

    func loadDailyLesson(for date: Date = .now) throws -> DailyLesson? {
        let key = Self.dateKey(from: date)
        let descriptor = FetchDescriptor<CachedDailyLessonEntity>(
            predicate: #Predicate { $0.assignmentDateKey == key }
        )
        guard let entity = try modelContext.fetch(descriptor).first else {
            return nil
        }
        return try decoder.decode(DailyLesson.self, from: entity.payload)
    }

    func upsertArchiveMetadata(_ words: [ArchiveWord]) throws {
        for row in words {
            let descriptor = FetchDescriptor<CachedWordMetadataEntity>(
                predicate: #Predicate { $0.wordID == row.word.id }
            )
            if let existing = try modelContext.fetch(descriptor).first {
                existing.lemma = row.word.lemma
                existing.statusRaw = row.status.rawValue
                existing.isFavorited = row.isFavorited
                existing.nextReviewAt = row.nextReviewAt
                existing.updatedAt = .now
            } else {
                let entity = CachedWordMetadataEntity(
                    wordID: row.word.id,
                    lemma: row.word.lemma,
                    statusRaw: row.status.rawValue,
                    isFavorited: row.isFavorited,
                    nextReviewAt: row.nextReviewAt
                )
                modelContext.insert(entity)
            }
        }
        try modelContext.save()
    }

    func loadArchiveMetadata() throws -> [CachedWordMetadataEntity] {
        let descriptor = FetchDescriptor<CachedWordMetadataEntity>(
            sortBy: [SortDescriptor(\CachedWordMetadataEntity.updatedAt, order: .reverse)]
        )
        return try modelContext.fetch(descriptor)
    }

    private static func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}
