import Foundation
import SwiftData

@MainActor
protocol DailyLessonCaching {
    func saveDailyLesson(_ lesson: DailyLesson, for date: Date) throws
    func loadDailyLesson(for date: Date) throws -> DailyLesson?
}

@MainActor
final class LocalCacheStore: DailyLessonCaching {
    private let modelContainer: ModelContainer?
    private let modelContext: ModelContext
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(modelContext: ModelContext, modelContainer: ModelContainer? = nil) {
        self.modelContainer = modelContainer
        self.modelContext = modelContext
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
    }

    convenience init(modelContainer: ModelContainer) {
        self.init(modelContext: modelContainer.mainContext, modelContainer: modelContainer)
    }

    func saveDailyLesson(_ lesson: DailyLesson, for date: Date = .now) throws {
        let key = Self.dateKey(from: date)
        let data = try encoder.encode(lesson)

        if let existing = try fetchCachedDailyLessons().first(where: { $0.assignmentDateKey == key }) {
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
        guard let entity = try fetchCachedDailyLessons().first(where: { $0.assignmentDateKey == key }) else {
            return nil
        }
        return try decoder.decode(DailyLesson.self, from: entity.payload)
    }

    func upsertArchiveMetadata(_ words: [ArchiveWord]) throws {
        for row in words {
            if let existing = try fetchCachedWordMetadata().first(where: { $0.wordID == row.word.id }) {
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
        try fetchCachedWordMetadata().sorted { $0.updatedAt > $1.updatedAt }
    }

    func saveWordEnrichment(_ enrichment: WordEnrichmentSnapshot, for wordID: UUID) throws {
        let data = try encoder.encode(enrichment)

        if let existing = try fetchCachedWordEnrichments().first(where: { $0.wordID == wordID }) {
            existing.payload = data
            existing.updatedAt = .now
        } else {
            modelContext.insert(CachedWordEnrichmentEntity(wordID: wordID, payload: data))
        }

        try modelContext.save()
    }

    func loadWordEnrichment(for wordID: UUID) throws -> CachedWordEnrichment? {
        guard let entity = try fetchCachedWordEnrichments().first(where: { $0.wordID == wordID }) else {
            return nil
        }

        let payload = try decoder.decode(WordEnrichmentSnapshot.self, from: entity.payload)
        return CachedWordEnrichment(wordID: wordID, payload: payload, cachedAt: entity.updatedAt)
    }

    func removeExpiredWordEnrichments(olderThan cutoffDate: Date) throws {
        let descriptor = FetchDescriptor<CachedWordEnrichmentEntity>()
        let entities = try modelContext.fetch(descriptor)

        for entity in entities where entity.updatedAt < cutoffDate {
            modelContext.delete(entity)
        }

        if modelContext.hasChanges {
            try modelContext.save()
        }
    }

    private static func dateKey(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func fetchCachedDailyLessons() throws -> [CachedDailyLessonEntity] {
        try modelContext.fetch(FetchDescriptor<CachedDailyLessonEntity>())
    }

    private func fetchCachedWordMetadata() throws -> [CachedWordMetadataEntity] {
        try modelContext.fetch(FetchDescriptor<CachedWordMetadataEntity>())
    }

    private func fetchCachedWordEnrichments() throws -> [CachedWordEnrichmentEntity] {
        try modelContext.fetch(FetchDescriptor<CachedWordEnrichmentEntity>())
    }
}
