import Foundation
import Supabase

final class SupabaseOnboardingService: OnboardingServiceProtocol {
    private let store: LocalKeyValueStore
    private let client: SupabaseClient
    private let key = "linguadaily.onboarding.state"

    init(config: SupabaseConfig, store: LocalKeyValueStore) {
        self.store = store
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func loadOnboardingState() throws -> OnboardingState {
        try store.get(OnboardingState.self, for: key) ?? .empty
    }

    func saveOnboardingState(_ state: OnboardingState) throws {
        try store.set(state, for: key)
    }

    func syncAuthenticatedState(_ state: OnboardingState) async throws {
        do {
            let session = try await client.auth.session
            let user = session.user
            let timezone = TimeZone.current.identifier
            let languageID = try await resolveLanguageID(for: state.language?.code)

            if let profilePayload = Self.makeProfileUpsert(
                userID: user.id,
                email: user.email ?? "",
                state: state,
                languageID: languageID,
                timezone: timezone
            ) {
                try await client
                    .from("profiles")
                    .upsert(profilePayload, onConflict: "id", returning: .minimal)
                    .execute()
            }

            if let notificationPayload = Self.makeNotificationPreferenceUpsert(
                userID: user.id,
                state: state,
                timezone: timezone
            ) {
                try await client
                    .from("notification_preferences")
                    .upsert(notificationPayload, onConflict: "user_id", returning: .minimal)
                    .execute()
            }
        } catch {
            throw normalize(error)
        }
    }

    private func resolveLanguageID(for code: String?) async throws -> UUID? {
        guard let code = code?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
              !code.isEmpty else {
            return nil
        }

        do {
            let languages: [LanguageDTO] = try await client
                .from("languages")
                .select("id,code,name,native_name,is_active")
                .eq("code", value: code)
                .limit(1)
                .execute()
                .value
            return languages.first?.id
        } catch {
            throw normalize(error)
        }
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? "Could not sync onboarding state." : message)
    }

    static func makeProfileUpsert(
        userID: UUID,
        email: String,
        state: OnboardingState,
        languageID: UUID?,
        timezone: String,
        now: Date = .now
    ) -> OnboardingProfileUpsertDTO? {
        let hasMeaningfulSelections = state.goal != nil
            || state.level != nil
            || state.reminderTime != nil
            || languageID != nil

        guard hasMeaningfulSelections else {
            return nil
        }

        return OnboardingProfileUpsertDTO(
            id: userID,
            email: email,
            learning_goal: state.goal,
            active_language_id: languageID,
            level: state.level,
            reminder_time: SupabaseFieldParser.sqlTimeString(from: state.reminderTime),
            timezone: timezone,
            onboarding_completed_at: state.isCompleted ? now : nil
        )
    }

    static func makeNotificationPreferenceUpsert(
        userID: UUID,
        state: OnboardingState,
        timezone: String
    ) -> NotificationPreferenceUpsertDTO? {
        guard let reminderTime = SupabaseFieldParser.sqlTimeString(from: state.reminderTime) else {
            return nil
        }

        return NotificationPreferenceUpsertDTO(
            user_id: userID,
            is_enabled: nil,
            reminder_time: reminderTime,
            timezone: timezone
        )
    }
}

struct OnboardingProfileUpsertDTO: Encodable {
    let id: UUID
    let email: String
    let learning_goal: LearningGoal?
    let active_language_id: UUID?
    let level: LearningLevel?
    let reminder_time: String?
    let timezone: String?
    let onboarding_completed_at: Date?
}

struct NotificationPreferenceUpsertDTO: Encodable {
    let user_id: UUID
    let is_enabled: Bool?
    let reminder_time: String
    let timezone: String
}
