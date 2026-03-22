import Foundation

@MainActor
final class StubTranslationService: TranslationServiceProtocol {
    private var storedTranslations: [SavedTranslation]

    init(initialTranslations: [SavedTranslation] = []) {
        self.storedTranslations = initialTranslations.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func fetchSavedTranslations() async throws -> [SavedTranslation] {
        storedTranslations.sorted(by: { $0.createdAt > $1.createdAt })
    }

    func createSavedTranslation(from draft: TranslationDraft, isFavorited: Bool) async throws -> SavedTranslation {
        let now = Date()
        let translation = SavedTranslation(
            id: UUID(),
            inputMode: draft.inputMode,
            sourceText: draft.sourceText,
            translatedText: draft.translatedText,
            sourceLanguage: draft.sourceLanguage,
            targetLanguage: draft.targetLanguage,
            isSaved: true,
            isFavorited: isFavorited,
            transcriptionText: draft.transcriptionText,
            extractedText: draft.extractedText,
            sourceImageURL: draft.sourceImageURL,
            detectionConfidence: draft.detectionConfidence,
            sessionID: draft.sessionID,
            createdAt: now,
            updatedAt: now
        )
        storedTranslations.removeAll { $0.id == translation.id }
        storedTranslations.insert(translation, at: 0)
        return translation
    }

    func updateSavedTranslation(id: UUID, isFavorited: Bool) async throws -> SavedTranslation {
        guard let index = storedTranslations.firstIndex(where: { $0.id == id }) else {
            throw AppError.unknown("Could not find the saved translation.")
        }

        let existing = storedTranslations[index]
        let updated = SavedTranslation(
            id: existing.id,
            inputMode: existing.inputMode,
            sourceText: existing.sourceText,
            translatedText: existing.translatedText,
            sourceLanguage: existing.sourceLanguage,
            targetLanguage: existing.targetLanguage,
            isSaved: true,
            isFavorited: isFavorited,
            transcriptionText: existing.transcriptionText,
            extractedText: existing.extractedText,
            sourceImageURL: existing.sourceImageURL,
            detectionConfidence: existing.detectionConfidence,
            sessionID: existing.sessionID,
            createdAt: existing.createdAt,
            updatedAt: Date()
        )
        storedTranslations[index] = updated
        return updated
    }

    func deleteSavedTranslation(id: UUID) async throws {
        storedTranslations.removeAll { $0.id == id }
    }
}
