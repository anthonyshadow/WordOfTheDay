import Foundation
import Supabase

final class SupabaseTranslationService: TranslationServiceProtocol {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchSavedTranslations() async throws -> [SavedTranslation] {
        let userID = try await currentUserID()

        do {
            let rows: [SavedTranslationDTO] = try await client
                .from("translations")
                .select(Self.selectFields)
                .eq("user_id", value: userID)
                .eq("is_saved", value: true)
                .order("created_at", ascending: false)
                .execute()
                .value
            return rows.map { $0.toModel() }
        } catch {
            throw normalize(error, fallback: "Could not load your saved translations.")
        }
    }

    func createSavedTranslation(from draft: TranslationDraft, isFavorited: Bool) async throws -> SavedTranslation {
        let userID = try await currentUserID()
        let translationID = UUID()

        do {
            try await client
                .from("translations")
                .insert(
                    SavedTranslationInsertDTO(
                        id: translationID,
                        user_id: userID,
                        input_mode: draft.inputMode,
                        source_text: draft.sourceText,
                        translated_text: draft.translatedText,
                        source_language: draft.sourceLanguage,
                        target_language: draft.targetLanguage,
                        is_saved: true,
                        is_favorited: isFavorited,
                        transcription_text: draft.transcriptionText,
                        extracted_text: draft.extractedText,
                        source_image_url: draft.sourceImageURL?.absoluteString,
                        detection_confidence: draft.detectionConfidence,
                        session_id: draft.sessionID
                    ),
                    returning: .minimal
                )
                .execute()

            guard let savedTranslation = try await fetchSavedTranslation(id: translationID, userID: userID) else {
                throw AppError.network("Could not save the translation.")
            }

            return savedTranslation
        } catch {
            throw normalize(error, fallback: "Could not save the translation.")
        }
    }

    func updateSavedTranslation(id: UUID, isFavorited: Bool) async throws -> SavedTranslation {
        let userID = try await currentUserID()

        do {
            try await client
                .from("translations")
                .update(
                    SavedTranslationFavoriteUpdateDTO(
                        is_saved: true,
                        is_favorited: isFavorited
                    ),
                    returning: .minimal
                )
                .eq("id", value: id)
                .eq("user_id", value: userID)
                .execute()

            guard let savedTranslation = try await fetchSavedTranslation(id: id, userID: userID) else {
                throw AppError.network("Could not update the saved translation.")
            }

            return savedTranslation
        } catch {
            throw normalize(error, fallback: "Could not update the saved translation.")
        }
    }

    func deleteSavedTranslation(id: UUID) async throws {
        let userID = try await currentUserID()

        do {
            try await client
                .from("translations")
                .delete(returning: .minimal)
                .eq("id", value: id)
                .eq("user_id", value: userID)
                .execute()
        } catch {
            throw normalize(error, fallback: "Could not remove the saved translation.")
        }
    }

    private func currentUserID() async throws -> UUID {
        do {
            let session = try await client.auth.session
            return session.user.id
        } catch {
            throw normalize(error, fallback: "Could not authenticate the translation request.")
        }
    }

    private func fetchSavedTranslation(id: UUID, userID: UUID) async throws -> SavedTranslation? {
        do {
            let rows: [SavedTranslationDTO] = try await client
                .from("translations")
                .select(Self.selectFields)
                .eq("id", value: id)
                .eq("user_id", value: userID)
                .limit(1)
                .execute()
                .value
            return rows.first?.toModel()
        } catch {
            throw normalize(error, fallback: "Could not load the saved translation.")
        }
    }

    private func normalize(_ error: Error, fallback: String) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? fallback : message)
    }

    private static let selectFields = """
        id,
        input_mode,
        source_text,
        translated_text,
        source_language,
        target_language,
        is_saved,
        is_favorited,
        transcription_text,
        extracted_text,
        source_image_url,
        detection_confidence,
        session_id,
        created_at,
        updated_at
    """
}
