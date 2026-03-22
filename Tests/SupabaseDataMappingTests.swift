import XCTest
import Supabase
@testable import LinguaDaily

final class SupabaseDataMappingTests: XCTestCase {
    func testMakeLessonMapsFlagsAndLanguageName() {
        let word = makeWordDTO()
        let progress = makeProgressDTO(status: .reviewDue, isFavorited: true, isSavedForReview: true)

        let lesson = SupabaseDailyLessonService.makeLesson(
            assignmentID: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            assignmentDateKey: "2026-03-21",
            dayNumber: 9,
            word: word,
            progress: progress
        )

        XCTAssertEqual(lesson.languageName, "French")
        XCTAssertEqual(lesson.word.lemma, "bonjour")
        XCTAssertTrue(lesson.isLearned)
        XCTAssertTrue(lesson.isFavorited)
        XCTAssertTrue(lesson.isSavedForReview)
        XCTAssertEqual(lesson.dayNumber, 9)
    }

    func testMergeProgressPreservesMasteredStateOnFavoriteOnlyChange() {
        let existing = makeProgressDTO(status: .mastered, isFavorited: false, isSavedForReview: false)

        let merged = SupabaseDailyLessonService.mergeProgress(
            userID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            wordID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            existing: existing,
            isLearned: nil,
            isFavorited: true,
            isSavedForReview: nil,
            now: Date(timeIntervalSince1970: 1_710_000_000)
        )

        XCTAssertEqual(merged.status, .mastered)
        XCTAssertTrue(merged.is_favorited)
        XCTAssertFalse(merged.is_saved_for_review)
    }

    func testMergeProgressMarksReviewDueWhenSavedForReview() {
        let merged = SupabaseDailyLessonService.mergeProgress(
            userID: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            wordID: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            existing: nil,
            isLearned: true,
            isFavorited: false,
            isSavedForReview: true,
            now: Date(timeIntervalSince1970: 1_710_000_000)
        )

        XCTAssertEqual(merged.status, .reviewDue)
        XCTAssertNotNil(merged.next_review_at)
        XCTAssertNotNil(merged.learned_at)
    }

    func testMakeUserProfileFallsBackToEmailAndNotificationPreference() {
        let user = User(
            id: UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!,
            appMetadata: [:],
            userMetadata: [:],
            aud: "authenticated",
            confirmationSentAt: nil,
            recoverySentAt: nil,
            emailChangeSentAt: nil,
            newEmail: nil,
            invitedAt: nil,
            actionLink: nil,
            email: "alex.carter@example.com",
            phone: nil,
            createdAt: Date(timeIntervalSince1970: 1_700_000_000),
            confirmedAt: nil,
            emailConfirmedAt: nil,
            phoneConfirmedAt: nil,
            lastSignInAt: nil,
            role: nil,
            updatedAt: Date(timeIntervalSince1970: 1_700_000_000),
            identities: nil,
            isAnonymous: false,
            factors: nil
        )

        let profile = SupabaseProgressService.makeUserProfile(
            profile: nil,
            notificationPreference: NotificationPreferenceDTO(reminder_time: "07:30:00", timezone: "America/Toronto"),
            user: user,
            currentStreakDays: 4,
            bestStreakDays: 9
        )

        XCTAssertEqual(profile.displayName, "Alex Carter")
        XCTAssertEqual(profile.email, "alex.carter@example.com")
        XCTAssertEqual(profile.timezoneIdentifier, "America/Toronto")
        XCTAssertEqual(Calendar.current.component(.hour, from: profile.reminderTime), 7)
        XCTAssertEqual(profile.learningGoal, .travel)
        XCTAssertEqual(profile.level, .beginner)
        XCTAssertEqual(profile.currentStreakDays, 4)
        XCTAssertEqual(profile.bestStreakDays, 9)
    }

    func testMakeWeeklyActivityBucketsReviewEventsIntoCurrentWeek() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let monday = calendar.date(from: DateComponents(year: 2024, month: 3, day: 25))!

        let metrics = [
            ProgressMetricsDTO(
                status: .learned,
                total_reviews: 1,
                correct_reviews: 1,
                learned_at: monday,
                last_reviewed_at: nil,
                word: ProgressMetricsWordDTO(part_of_speech: "noun")
            ),
            ProgressMetricsDTO(
                status: .reviewDue,
                total_reviews: 2,
                correct_reviews: 1,
                learned_at: nil,
                last_reviewed_at: calendar.date(byAdding: .day, value: 2, to: monday),
                word: ProgressMetricsWordDTO(part_of_speech: "verb")
            )
        ]

        let points = SupabaseProgressService.makeWeeklyActivity(
            from: metrics,
            calendar: calendar,
            referenceDate: calendar.date(byAdding: .day, value: 3, to: monday) ?? monday
        )

        XCTAssertEqual(points.count, 7)
        XCTAssertEqual(points[0].weekdayLabel, "Mon")
        XCTAssertEqual(points[0].score, 12)
        XCTAssertEqual(points[2].weekdayLabel, "Wed")
        XCTAssertEqual(points[2].score, 12)
    }

    func testCompletedOnboardingStateCopiesProfileSelections() {
        let reminder = Date(timeIntervalSince1970: 1_710_000_000)
        let profile = UserProfile(
            id: UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!,
            email: "alex.carter@example.com",
            displayName: "Alex Carter",
            activeLanguage: SampleData.french,
            learningGoal: .work,
            level: .intermediate,
            preferredAccent: "parisian",
            dailyLearningMode: .balanced,
            appearancePreference: .system,
            reminderTime: reminder,
            timezoneIdentifier: "America/Toronto",
            currentStreakDays: 6,
            bestStreakDays: 12,
            joinedAt: Date(timeIntervalSince1970: 1_700_000_000)
        )

        let state = OnboardingState.completed(from: profile)

        XCTAssertEqual(state.goal, .work)
        XCTAssertEqual(state.language?.code, "fr")
        XCTAssertEqual(state.level, .intermediate)
        XCTAssertEqual(state.reminderTime, reminder)
        XCTAssertTrue(state.isCompleted)
    }

    func testMakeProfileUpsertUsesResolvedLanguageAndReminderTime() {
        let reminder = Calendar.current.date(bySettingHour: 8, minute: 30, second: 0, of: Date())!
        let userID = UUID(uuidString: "AAAAAAAA-1111-2222-3333-BBBBBBBBBBBB")!
        let languageID = UUID(uuidString: "CCCCCCCC-1111-2222-3333-DDDDDDDDDDDD")!
        let state = OnboardingState(
            goal: .travel,
            language: SampleData.french,
            level: .beginner,
            reminderTime: reminder,
            hasSeenNotificationEducation: true,
            hasRequestedNotificationPermission: false,
            isCompleted: true
        )

        let payload = SupabaseOnboardingService.makeProfileUpsert(
            userID: userID,
            email: "alex.carter@example.com",
            state: state,
            languageID: languageID,
            displayName: "Alex Carter",
            timezone: "America/Toronto",
            now: Date(timeIntervalSince1970: 1_720_000_000)
        )

        XCTAssertEqual(payload?.id, userID)
        XCTAssertEqual(payload?.display_name, "Alex Carter")
        XCTAssertEqual(payload?.learning_goal, .travel)
        XCTAssertEqual(payload?.active_language_id, languageID)
        XCTAssertEqual(payload?.level, .beginner)
        XCTAssertEqual(payload?.reminder_time, "08:30:00")
        XCTAssertEqual(payload?.timezone, "America/Toronto")
        XCTAssertNotNil(payload?.onboarding_completed_at)
    }

    func testCalculateStreaksComputesCurrentAndBestRuns() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let referenceDate = calendar.date(from: DateComponents(year: 2026, month: 3, day: 22))!
        let assignmentDates = [
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 18))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 19))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 21))!,
            calendar.date(from: DateComponents(year: 2026, month: 3, day: 22))!
        ]

        let streaks = SupabaseProgressService.calculateStreaks(
            assignmentDates: assignmentDates,
            calendar: calendar,
            referenceDate: referenceDate
        )

        XCTAssertEqual(streaks.current, 2)
        XCTAssertEqual(streaks.best, 2)
    }

    func testBestRetentionCategoryUsesActualPartOfSpeechMetrics() {
        let metrics = [
            ProgressMetricsDTO(
                status: .mastered,
                total_reviews: 6,
                correct_reviews: 6,
                learned_at: Date(timeIntervalSince1970: 1_700_000_000),
                last_reviewed_at: Date(timeIntervalSince1970: 1_700_010_000),
                word: ProgressMetricsWordDTO(part_of_speech: "verb")
            ),
            ProgressMetricsDTO(
                status: .mastered,
                total_reviews: 5,
                correct_reviews: 5,
                learned_at: Date(timeIntervalSince1970: 1_700_020_000),
                last_reviewed_at: Date(timeIntervalSince1970: 1_700_030_000),
                word: ProgressMetricsWordDTO(part_of_speech: "verb")
            ),
            ProgressMetricsDTO(
                status: .learned,
                total_reviews: 3,
                correct_reviews: 2,
                learned_at: Date(timeIntervalSince1970: 1_700_040_000),
                last_reviewed_at: Date(timeIntervalSince1970: 1_700_050_000),
                word: ProgressMetricsWordDTO(part_of_speech: "noun")
            )
        ]

        let category = SupabaseProgressService.bestRetentionCategory(
            from: metrics,
            fallbackLanguageName: "Italian"
        )

        XCTAssertEqual(category, "Verbs")
    }

    func testSavedTranslationDTOMapsCameraMetadataIntoModel() {
        let createdAt = Date(timeIntervalSince1970: 1_720_000_000)
        let dto = SavedTranslationDTO(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            input_mode: .camera,
            source_text: "Uscita",
            translated_text: "Exit",
            source_language: "it",
            target_language: "en",
            is_saved: true,
            is_favorited: true,
            transcription_text: nil,
            extracted_text: "Uscita",
            source_image_url: "https://cdn.linguadaily.app/translations/uscita.jpg",
            detection_confidence: 0.84,
            session_id: "camera-session",
            created_at: createdAt,
            updated_at: createdAt
        )

        let translation = dto.toModel()

        XCTAssertEqual(translation.inputMode, .camera)
        XCTAssertEqual(translation.sourceText, "Uscita")
        XCTAssertEqual(translation.translatedText, "Exit")
        XCTAssertEqual(translation.extractedText, "Uscita")
        XCTAssertEqual(translation.sourceImageURL?.absoluteString, "https://cdn.linguadaily.app/translations/uscita.jpg")
        XCTAssertEqual(translation.detectionConfidence, 0.84)
        XCTAssertEqual(translation.sessionID, "camera-session")
        XCTAssertTrue(translation.isSaved)
        XCTAssertTrue(translation.isFavorited)
    }

    private func makeWordDTO() -> WordWithRelationsDTO {
        WordWithRelationsDTO(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            lemma: "bonjour",
            transliteration: nil,
            pronunciation_ipa: "/bɔ̃.ʒuʁ/",
            part_of_speech: "interjection",
            cefr_level: "A1",
            frequency_rank: 20,
            definition: "Hello",
            usage_notes: "Greeting",
            language: LanguageDTO(
                id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
                code: "fr",
                name: "French",
                native_name: "Francais",
                is_active: true
            ),
            example_sentences: [
                ExampleSentenceDTO(
                    id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
                    word_id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    sentence: "Bonjour !",
                    translation: "Hello!",
                    order_index: 1
                )
            ],
            word_audio: [
                WordAudioDTO(
                    id: UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
                    word_id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
                    accent: "parisian",
                    speed: "native",
                    audio_url: "https://example.com/native.mp3",
                    duration_ms: 1400
                )
            ]
        )
    }

    private func makeProgressDTO(status: WordStatus, isFavorited: Bool, isSavedForReview: Bool) -> UserWordProgressDTO {
        UserWordProgressDTO(
            id: UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
            user_id: UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
            word_id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            status: status,
            is_favorited: isFavorited,
            is_saved_for_review: isSavedForReview,
            consecutive_correct: 3,
            total_reviews: 4,
            correct_reviews: 3,
            current_interval_days: 7,
            next_review_at: nil,
            learned_at: Date(timeIntervalSince1970: 1_700_000_000),
            last_reviewed_at: Date(timeIntervalSince1970: 1_700_000_000)
        )
    }
}
