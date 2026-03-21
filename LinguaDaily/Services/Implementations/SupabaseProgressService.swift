import Foundation
import Supabase

final class SupabaseProgressService: ProgressServiceProtocol {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchProgress() async throws -> ProgressSnapshot {
        let bundle = try await fetchProfileBundle()
        let metrics = try await fetchProgressMetrics(userID: bundle.user.id)

        let totalReviews = metrics.reduce(0) { $0 + $1.total_reviews }
        let correctReviews = metrics.reduce(0) { $0 + $1.correct_reviews }
        let wordsLearned = metrics.filter { $0.status != .new || $0.learned_at != nil }.count
        let masteredCount = metrics.filter { $0.status == .mastered }.count

        return ProgressSnapshot(
            currentStreakDays: bundle.profile?.streak_current ?? 0,
            bestStreakDays: bundle.profile?.streak_best ?? 0,
            wordsLearned: wordsLearned,
            masteredCount: masteredCount,
            reviewAccuracy: totalReviews > 0 ? Double(correctReviews) / Double(totalReviews) : 0,
            weeklyActivity: Self.makeWeeklyActivity(from: metrics),
            bestRetentionCategory: bundle.profile?.active_language.map { "\($0.name) vocabulary" } ?? "Current words"
        )
    }

    func fetchProfile() async throws -> UserProfile {
        let bundle = try await fetchProfileBundle()
        return Self.makeUserProfile(
            profile: bundle.profile,
            notificationPreference: bundle.notificationPreference,
            user: bundle.user
        )
    }

    private func fetchProfileBundle() async throws -> ProfileBundle {
        do {
            let session = try await client.auth.session
            let user = session.user
            let profiles: [ProfileDTO] = try await client
                .from("profiles")
                .select("""
                    id,
                    email,
                    display_name,
                    learning_goal,
                    active_language_id,
                    level,
                    reminder_time,
                    timezone,
                    streak_current,
                    streak_best,
                    created_at,
                    active_language:languages!profiles_active_language_id_fkey(
                        id,
                        code,
                        name,
                        native_name,
                        is_active
                    )
                """)
                .eq("id", value: user.id)
                .limit(1)
                .execute()
                .value

            let notificationPreferences: [NotificationPreferenceDTO] = try await client
                .from("notification_preferences")
                .select("reminder_time,timezone")
                .eq("user_id", value: user.id)
                .limit(1)
                .execute()
                .value

            return ProfileBundle(
                user: user,
                profile: profiles.first,
                notificationPreference: notificationPreferences.first
            )
        } catch {
            throw normalize(error)
        }
    }

    private func fetchProgressMetrics(userID: UUID) async throws -> [ProgressMetricsDTO] {
        do {
            return try await client
                .from("user_word_progress")
                .select("status,total_reviews,correct_reviews,learned_at,last_reviewed_at")
                .eq("user_id", value: userID)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func normalize(_ error: Error) -> AppError {
        if let appError = error as? AppError {
            return appError
        }

        let message = error.localizedDescription.trimmingCharacters(in: .whitespacesAndNewlines)
        return AppError.network(message.isEmpty ? "Could not load your profile." : message)
    }

    static func makeUserProfile(
        profile: ProfileDTO?,
        notificationPreference: NotificationPreferenceDTO?,
        user: User
    ) -> UserProfile {
        let email = profile?.email ?? user.email ?? "user@example.com"
        let activeLanguage = profile?.active_language?.toModel()

        return UserProfile(
            id: user.id,
            email: email,
            displayName: resolvedDisplayName(profile: profile, user: user, email: email),
            activeLanguage: activeLanguage,
            learningGoal: profile?.learning_goal ?? .travel,
            level: profile?.level ?? .beginner,
            reminderTime: SupabaseFieldParser.reminderTime(from: profile?.reminder_time)
                ?? SupabaseFieldParser.reminderTime(from: notificationPreference?.reminder_time)
                ?? SupabaseFieldParser.defaultReminderTime(),
            timezoneIdentifier: profile?.timezone
                ?? notificationPreference?.timezone
                ?? TimeZone.current.identifier,
            joinedAt: profile?.created_at ?? user.createdAt
        )
    }

    static func makeWeeklyActivity(
        from metrics: [ProgressMetricsDTO],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> [WeeklyActivityPoint] {
        let startOfReferenceDay = calendar.startOfDay(for: referenceDate)
        let referenceWeekday = calendar.component(.weekday, from: startOfReferenceDay)
        let mondayOffset = (referenceWeekday + 5) % 7
        let monday = calendar.date(byAdding: .day, value: -mondayOffset, to: startOfReferenceDay) ?? startOfReferenceDay

        var activityByDay: [Date: Int] = [:]
        for metric in metrics {
            for eventDate in [metric.last_reviewed_at, metric.learned_at].compactMap({ $0 }) {
                let startOfDay = calendar.startOfDay(for: eventDate)
                activityByDay[startOfDay, default: 0] += 1
            }
        }

        let weekdayLabels = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]
        return weekdayLabels.enumerated().map { index, label in
            let day = calendar.date(byAdding: .day, value: index, to: monday) ?? monday
            return WeeklyActivityPoint(
                id: UUID(),
                weekdayLabel: label,
                score: activityByDay[day, default: 0] * 12
            )
        }
    }

    private static func resolvedDisplayName(profile: ProfileDTO?, user: User, email: String) -> String {
        if let displayName = profile?.display_name?.trimmingCharacters(in: .whitespacesAndNewlines), !displayName.isEmpty {
            return displayName
        }

        for key in ["display_name", "full_name", "name"] {
            if let metadataName = user.userMetadata[key]?.stringValue?.trimmingCharacters(in: .whitespacesAndNewlines), !metadataName.isEmpty {
                return metadataName
            }
        }

        let localPart = email.split(separator: "@").first.map(String.init) ?? "Learner"
        return localPart
            .split(separator: ".")
            .map { $0.capitalized }
            .joined(separator: " ")
    }
}

private struct ProfileBundle {
    let user: User
    let profile: ProfileDTO?
    let notificationPreference: NotificationPreferenceDTO?
}
