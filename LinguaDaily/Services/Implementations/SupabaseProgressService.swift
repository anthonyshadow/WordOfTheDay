import Foundation
import Supabase

final class SupabaseProgressService: ProgressServiceProtocol {
    private let client: SupabaseClient

    init(config: SupabaseConfig) {
        self.client = SupabaseClient(supabaseURL: config.projectURL, supabaseKey: config.anonKey)
    }

    func fetchProgress() async throws -> ProgressSnapshot {
        let bundle = try await fetchProfileBundle()
        async let metricsTask = fetchProgressMetrics(userID: bundle.user.id)
        async let assignmentDatesTask = fetchAssignmentDates(userID: bundle.user.id)

        let metrics = try await metricsTask
        let assignmentDates = try await assignmentDatesTask
        let streaks = Self.calculateStreaks(assignmentDates: assignmentDates)

        let totalReviews = metrics.reduce(0) { $0 + $1.total_reviews }
        let correctReviews = metrics.reduce(0) { $0 + $1.correct_reviews }
        let wordsLearned = metrics.filter { $0.status != .new || $0.learned_at != nil }.count
        let masteredCount = metrics.filter { $0.status == .mastered }.count

        return ProgressSnapshot(
            currentStreakDays: streaks.current,
            bestStreakDays: streaks.best,
            wordsLearned: wordsLearned,
            masteredCount: masteredCount,
            reviewAccuracy: totalReviews > 0 ? Double(correctReviews) / Double(totalReviews) : 0,
            weeklyActivity: Self.makeWeeklyActivity(from: metrics),
            bestRetentionCategory: Self.bestRetentionCategory(
                from: metrics,
                fallbackLanguageName: bundle.profile?.active_language?.name
            )
        )
    }

    func fetchProfile() async throws -> UserProfile {
        let bundle = try await fetchProfileBundle()
        let streaks = Self.calculateStreaks(assignmentDates: try await fetchAssignmentDates(userID: bundle.user.id))
        return Self.makeUserProfile(
            profile: bundle.profile,
            notificationPreference: bundle.notificationPreference,
            user: bundle.user,
            currentStreakDays: streaks.current,
            bestStreakDays: streaks.best
        )
    }

    func updateProfile(_ request: UserProfileUpdateRequest) async throws -> UserProfile {
        do {
            let session = try await client.auth.session
            let displayName = request.displayName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !displayName.isEmpty else {
                throw AppError.validation("Display name cannot be empty.")
            }

            try await client
                .from("profiles")
                .upsert(
                    ProfileUpdateDTO(
                        id: session.user.id,
                        email: session.user.email ?? "",
                        display_name: displayName,
                        learning_goal: request.learningGoal,
                        active_language_id: request.activeLanguage?.id,
                        level: request.level,
                        preferred_accent: Self.normalizedAccent(request.preferredAccent),
                        daily_learning_mode: request.dailyLearningMode,
                        appearance: request.appearancePreference,
                        timezone: TimeZone.current.identifier
                    ),
                    onConflict: "id",
                    returning: .minimal
                )
                .execute()

            return try await fetchProfile()
        } catch {
            throw normalize(error)
        }
    }

    func fetchAvailableAccents(languageID: UUID?) async throws -> [String] {
        guard let languageID else {
            return []
        }

        do {
            let rows: [LanguageAccentContainerDTO] = try await client
                .from("words")
                .select("word_audio(accent)")
                .eq("language_id", value: languageID)
                .order("frequency_rank", ascending: true)
                .limit(200)
                .execute()
                .value

            let accents = Set(
                rows.flatMap(\.word_audio)
                    .map(\.accent)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )

            return accents.sorted {
                $0.localizedCaseInsensitiveCompare($1) == .orderedAscending
            }
        } catch {
            throw normalize(error)
        }
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
                    preferred_accent,
                    daily_learning_mode,
                    appearance,
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
                .select("""
                    status,
                    total_reviews,
                    correct_reviews,
                    learned_at,
                    last_reviewed_at,
                    word:words!user_word_progress_word_id_fkey(
                        part_of_speech
                    )
                """)
                .eq("user_id", value: userID)
                .execute()
                .value
        } catch {
            throw normalize(error)
        }
    }

    private func fetchAssignmentDates(userID: UUID) async throws -> [Date] {
        do {
            let rows: [AssignmentDateDTO] = try await client
                .from("daily_word_assignments")
                .select("assignment_date")
                .eq("user_id", value: userID)
                .order("assignment_date", ascending: true)
                .execute()
                .value

            return rows.compactMap { SupabaseFieldParser.sqlDate(from: $0.assignment_date) }
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
        user: User,
        currentStreakDays: Int,
        bestStreakDays: Int
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
            preferredAccent: normalizedAccent(profile?.preferred_accent),
            dailyLearningMode: profile?.daily_learning_mode ?? .balanced,
            appearancePreference: profile?.appearance ?? .system,
            reminderTime: SupabaseFieldParser.reminderTime(from: profile?.reminder_time)
                ?? SupabaseFieldParser.reminderTime(from: notificationPreference?.reminder_time)
                ?? SupabaseFieldParser.defaultReminderTime(),
            timezoneIdentifier: profile?.timezone
                ?? notificationPreference?.timezone
                ?? TimeZone.current.identifier,
            currentStreakDays: currentStreakDays,
            bestStreakDays: max(bestStreakDays, currentStreakDays),
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

    static func calculateStreaks(
        assignmentDates: [Date],
        calendar: Calendar = .current,
        referenceDate: Date = .now
    ) -> (current: Int, best: Int) {
        let sortedDays = Array(Set(assignmentDates.map { calendar.startOfDay(for: $0) })).sorted()
        guard !sortedDays.isEmpty else {
            return (0, 0)
        }

        var best = 1
        var running = 1
        for index in 1..<sortedDays.count {
            let previous = sortedDays[index - 1]
            let current = sortedDays[index]
            let difference = calendar.dateComponents([.day], from: previous, to: current).day ?? 0
            if difference == 1 {
                running += 1
            } else {
                best = max(best, running)
                running = 1
            }
        }
        best = max(best, running)

        guard let lastDay = sortedDays.last else {
            return (0, best)
        }

        let today = calendar.startOfDay(for: referenceDate)
        let daysSinceLast = calendar.dateComponents([.day], from: lastDay, to: today).day ?? 0
        guard daysSinceLast <= 1 else {
            return (0, best)
        }

        var current = 1
        for index in stride(from: sortedDays.count - 1, through: 1, by: -1) {
            let currentDay = sortedDays[index]
            let previousDay = sortedDays[index - 1]
            let difference = calendar.dateComponents([.day], from: previousDay, to: currentDay).day ?? 0
            guard difference == 1 else {
                break
            }
            current += 1
        }

        return (current, max(best, current))
    }

    static func bestRetentionCategory(
        from metrics: [ProgressMetricsDTO],
        fallbackLanguageName: String?
    ) -> String {
        var totalsByCategory: [String: CategoryProgressTotals] = [:]

        for metric in metrics {
            let category = categoryLabel(for: metric.word?.part_of_speech) ?? "Other"
            var totals = totalsByCategory[category, default: .empty]
            totals.learnedCount += metric.status != .new || metric.learned_at != nil ? 1 : 0
            totals.masteredCount += metric.status == .mastered ? 1 : 0
            totals.totalReviews += metric.total_reviews
            totals.correctReviews += metric.correct_reviews
            totalsByCategory[category] = totals
        }

        guard let bestCategory = totalsByCategory.max(by: { lhs, rhs in
            let lhsValue = lhs.value
            let rhsValue = rhs.value
            if lhsValue.masteredCount != rhsValue.masteredCount {
                return lhsValue.masteredCount < rhsValue.masteredCount
            }
            if lhsValue.accuracy != rhsValue.accuracy {
                return lhsValue.accuracy < rhsValue.accuracy
            }
            if lhsValue.learnedCount != rhsValue.learnedCount {
                return lhsValue.learnedCount < rhsValue.learnedCount
            }
            return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedDescending
        })?.key else {
            return fallbackLanguageName.map { "\($0) vocabulary" } ?? "Current words"
        }

        return bestCategory
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

    private static func categoryLabel(for partOfSpeech: String?) -> String? {
        guard let partOfSpeech = partOfSpeech?.trimmingCharacters(in: .whitespacesAndNewlines), !partOfSpeech.isEmpty else {
            return nil
        }

        switch partOfSpeech.lowercased() {
        case "noun":
            return "Nouns"
        case "verb":
            return "Verbs"
        case "adjective":
            return "Adjectives"
        case "adverb":
            return "Adverbs"
        case "phrase":
            return "Phrases"
        case "interjection":
            return "Interjections"
        default:
            return partOfSpeech.capitalized
        }
    }

    private static func normalizedAccent(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }
}

private struct ProfileBundle {
    let user: User
    let profile: ProfileDTO?
    let notificationPreference: NotificationPreferenceDTO?
}

private struct ProfileUpdateDTO: Encodable {
    let id: UUID
    let email: String
    let display_name: String
    let learning_goal: LearningGoal
    let active_language_id: UUID?
    let level: LearningLevel
    let preferred_accent: String?
    let daily_learning_mode: DailyLearningMode
    let appearance: AppearancePreference
    let timezone: String
}

private struct CategoryProgressTotals {
    var learnedCount: Int
    var masteredCount: Int
    var totalReviews: Int
    var correctReviews: Int

    static let empty = CategoryProgressTotals(
        learnedCount: 0,
        masteredCount: 0,
        totalReviews: 0,
        correctReviews: 0
    )

    var accuracy: Double {
        guard totalReviews > 0 else {
            return 0
        }

        return Double(correctReviews) / Double(totalReviews)
    }
}
