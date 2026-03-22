import Foundation

protocol TranslationServiceProtocol {
    func fetchSavedTranslations() async throws -> [SavedTranslation]
    func createSavedTranslation(from draft: TranslationDraft, isFavorited: Bool) async throws -> SavedTranslation
    func updateSavedTranslation(id: UUID, isFavorited: Bool) async throws -> SavedTranslation
    func deleteSavedTranslation(id: UUID) async throws
}
