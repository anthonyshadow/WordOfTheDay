import Foundation
import SwiftData

@Model
final class CachedDailyLessonEntity {
    @Attribute(.unique) var assignmentDateKey: String
    var payload: Data
    var updatedAt: Date

    init(assignmentDateKey: String, payload: Data, updatedAt: Date = .now) {
        self.assignmentDateKey = assignmentDateKey
        self.payload = payload
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedWordMetadataEntity {
    @Attribute(.unique) var wordID: UUID
    var lemma: String
    var statusRaw: String
    var isFavorited: Bool
    var nextReviewAt: Date?
    var updatedAt: Date

    init(
        wordID: UUID,
        lemma: String,
        statusRaw: String,
        isFavorited: Bool,
        nextReviewAt: Date?,
        updatedAt: Date = .now
    ) {
        self.wordID = wordID
        self.lemma = lemma
        self.statusRaw = statusRaw
        self.isFavorited = isFavorited
        self.nextReviewAt = nextReviewAt
        self.updatedAt = updatedAt
    }
}

@Model
final class CachedWordEnrichmentEntity {
    @Attribute(.unique) var wordID: UUID
    var payload: Data
    var updatedAt: Date

    init(wordID: UUID, payload: Data, updatedAt: Date = .now) {
        self.wordID = wordID
        self.payload = payload
        self.updatedAt = updatedAt
    }
}
