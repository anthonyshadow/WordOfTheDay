import Foundation

struct LanguageDTO: Decodable {
    let id: UUID
    let code: String
    let name: String
    let native_name: String
    let is_active: Bool
}

struct WordDTO: Decodable {
    let id: UUID
    let language_id: UUID
    let lemma: String
    let transliteration: String?
    let pronunciation_ipa: String?
    let pronunciation_guidance: String?
    let part_of_speech: String?
    let cefr_level: String?
    let frequency_rank: Int?
    let definition: String
    let usage_notes: String?
    let language_variant: String?
    let enrichment_source: String?
    let enrichment_updated_at: Date?

    init(
        id: UUID,
        language_id: UUID,
        lemma: String,
        transliteration: String? = nil,
        pronunciation_ipa: String? = nil,
        pronunciation_guidance: String? = nil,
        part_of_speech: String? = nil,
        cefr_level: String? = nil,
        frequency_rank: Int? = nil,
        definition: String,
        usage_notes: String? = nil,
        language_variant: String? = nil,
        enrichment_source: String? = nil,
        enrichment_updated_at: Date? = nil
    ) {
        self.id = id
        self.language_id = language_id
        self.lemma = lemma
        self.transliteration = transliteration
        self.pronunciation_ipa = pronunciation_ipa
        self.pronunciation_guidance = pronunciation_guidance
        self.part_of_speech = part_of_speech
        self.cefr_level = cefr_level
        self.frequency_rank = frequency_rank
        self.definition = definition
        self.usage_notes = usage_notes
        self.language_variant = language_variant
        self.enrichment_source = enrichment_source
        self.enrichment_updated_at = enrichment_updated_at
    }
}

struct ExampleSentenceDTO: Decodable {
    let id: UUID
    let word_id: UUID
    let sentence: String
    let translation: String
    let order_index: Int
    let source: String?

    init(
        id: UUID,
        word_id: UUID,
        sentence: String,
        translation: String,
        order_index: Int,
        source: String? = nil
    ) {
        self.id = id
        self.word_id = word_id
        self.sentence = sentence
        self.translation = translation
        self.order_index = order_index
        self.source = source
    }
}

struct WordAudioDTO: Decodable {
    let id: UUID
    let word_id: UUID
    let accent: String
    let speed: String
    let audio_url: String
    let duration_ms: Int?
    let source: String?
    let speaker_label: String?
    let provider_reference: String?

    init(
        id: UUID,
        word_id: UUID,
        accent: String,
        speed: String,
        audio_url: String,
        duration_ms: Int? = nil,
        source: String? = nil,
        speaker_label: String? = nil,
        provider_reference: String? = nil
    ) {
        self.id = id
        self.word_id = word_id
        self.accent = accent
        self.speed = speed
        self.audio_url = audio_url
        self.duration_ms = duration_ms
        self.source = source
        self.speaker_label = speaker_label
        self.provider_reference = provider_reference
    }
}

struct WordWithRelationsDTO: Decodable {
    let id: UUID
    let lemma: String
    let transliteration: String?
    let pronunciation_ipa: String?
    let pronunciation_guidance: String?
    let part_of_speech: String?
    let cefr_level: String?
    let frequency_rank: Int?
    let definition: String
    let usage_notes: String?
    let language_variant: String?
    let enrichment_source: String?
    let enrichment_updated_at: Date?
    let language: LanguageDTO?
    let example_sentences: [ExampleSentenceDTO]
    let word_audio: [WordAudioDTO]

    init(
        id: UUID,
        lemma: String,
        transliteration: String? = nil,
        pronunciation_ipa: String? = nil,
        pronunciation_guidance: String? = nil,
        part_of_speech: String? = nil,
        cefr_level: String? = nil,
        frequency_rank: Int? = nil,
        definition: String,
        usage_notes: String? = nil,
        language_variant: String? = nil,
        enrichment_source: String? = nil,
        enrichment_updated_at: Date? = nil,
        language: LanguageDTO? = nil,
        example_sentences: [ExampleSentenceDTO] = [],
        word_audio: [WordAudioDTO] = []
    ) {
        self.id = id
        self.lemma = lemma
        self.transliteration = transliteration
        self.pronunciation_ipa = pronunciation_ipa
        self.pronunciation_guidance = pronunciation_guidance
        self.part_of_speech = part_of_speech
        self.cefr_level = cefr_level
        self.frequency_rank = frequency_rank
        self.definition = definition
        self.usage_notes = usage_notes
        self.language_variant = language_variant
        self.enrichment_source = enrichment_source
        self.enrichment_updated_at = enrichment_updated_at
        self.language = language
        self.example_sentences = example_sentences
        self.word_audio = word_audio
    }
}

struct DailyWordAssignmentDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let assignment_date: String
    let source: String
}

struct DailyWordAssignmentWithWordDTO: Decodable {
    let id: UUID
    let assignment_date: String
    let word: WordWithRelationsDTO
}

struct UserWordProgressDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let status: WordStatus
    let is_favorited: Bool
    let is_saved_for_review: Bool
    let consecutive_correct: Int
    let total_reviews: Int
    let correct_reviews: Int
    let current_interval_days: Int
    let next_review_at: Date?
    let learned_at: Date?
    let last_reviewed_at: Date?
}

struct ReviewWordDTO: Decodable {
    let id: UUID
    let language_id: UUID
    let lemma: String
    let pronunciation_ipa: String?
    let definition: String
}

struct WordDefinitionDTO: Decodable {
    let id: UUID
    let language_id: UUID
    let definition: String
}

struct UserWordProgressWithWordDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let status: WordStatus
    let is_favorited: Bool
    let is_saved_for_review: Bool
    let consecutive_correct: Int
    let total_reviews: Int
    let correct_reviews: Int
    let current_interval_days: Int
    let next_review_at: Date?
    let learned_at: Date?
    let last_reviewed_at: Date?
    let word: ReviewWordDTO
}

struct ReviewQueueRowDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let due_at: Date
    let state: String
    let last_outcome_correct: Bool?
    let attempt_count: Int
    let selected_option: String?
}

struct ProfileDTO: Decodable {
    let id: UUID
    let email: String
    let display_name: String?
    let learning_goal: LearningGoal?
    let active_language_id: UUID?
    let level: LearningLevel?
    let preferred_accent: String?
    let daily_learning_mode: DailyLearningMode?
    let appearance: AppearancePreference?
    let reminder_time: String?
    let timezone: String?
    let streak_current: Int
    let streak_best: Int
    let created_at: Date
    let active_language: LanguageDTO?
}

struct ProfileLanguageSelectionDTO: Decodable {
    let active_language_id: UUID?
}

struct ProfileAccentSelectionDTO: Decodable {
    let preferred_accent: String?
}

struct NotificationPreferenceDTO: Decodable {
    let reminder_time: String
    let timezone: String
}

struct ProgressMetricsDTO: Decodable {
    let status: WordStatus
    let total_reviews: Int
    let correct_reviews: Int
    let learned_at: Date?
    let last_reviewed_at: Date?
    let word: ProgressMetricsWordDTO?
}

struct ProgressMetricsWordDTO: Decodable {
    let part_of_speech: String?
}

struct AssignmentDateDTO: Decodable {
    let assignment_date: String
}

struct WordAudioAccentValueDTO: Decodable {
    let accent: String
}

struct LanguageAccentContainerDTO: Decodable {
    let word_audio: [WordAudioAccentValueDTO]
}

struct SavedTranslationDTO: Decodable {
    let id: UUID
    let input_mode: TranslationInputMode
    let source_text: String
    let translated_text: String
    let source_language: String
    let target_language: String
    let is_saved: Bool
    let is_favorited: Bool
    let transcription_text: String?
    let extracted_text: String?
    let source_image_url: String?
    let detection_confidence: Double?
    let session_id: String?
    let created_at: Date
    let updated_at: Date
}

struct SavedTranslationInsertDTO: Encodable {
    let id: UUID
    let user_id: UUID
    let input_mode: TranslationInputMode
    let source_text: String
    let translated_text: String
    let source_language: String
    let target_language: String
    let is_saved: Bool
    let is_favorited: Bool
    let transcription_text: String?
    let extracted_text: String?
    let source_image_url: String?
    let detection_confidence: Double?
    let session_id: String?
}

struct SavedTranslationFavoriteUpdateDTO: Encodable {
    let is_saved: Bool
    let is_favorited: Bool
}

struct ReviewQueueInsertDTO: Encodable {
    let user_id: UUID
    let word_id: UUID
    let due_at: Date
    let state = "queued"
    let attempt_count: Int
}

struct ReviewQueueDueAtUpdateDTO: Encodable {
    let due_at: Date
}

struct ReviewQueueStateUpdateDTO: Encodable {
    let state: String
}

struct ReviewQueueCompletionUpdateDTO: Encodable {
    let state = "completed"
    let last_outcome_correct: Bool
    let attempt_count: Int
    let selected_option: String
}

extension LanguageDTO {
    func toModel() -> Language {
        Language(
            id: id,
            code: code,
            name: name,
            nativeName: native_name,
            isActive: is_active
        )
    }
}

extension WordWithRelationsDTO {
    var languageName: String {
        language?.name ?? "Language"
    }

    func toModel() -> Word {
        Word(
            id: id,
            languageCode: language?.code ?? "",
            lemma: lemma,
            transliteration: transliteration,
            pronunciationIPA: pronunciation_ipa ?? "",
            partOfSpeech: part_of_speech ?? "",
            cefrLevel: cefr_level ?? "",
            frequencyRank: frequency_rank ?? .max,
            definition: definition,
            usageNotes: usage_notes ?? "",
            examples: example_sentences
                .sorted(by: { $0.order_index < $1.order_index })
                .map {
                    ExampleSentence(
                        id: $0.id,
                        sentence: $0.sentence,
                        translation: $0.translation,
                        order: $0.order_index,
                        source: $0.source
                    )
                },
            audio: word_audio
                .sorted(by: { Self.audioSortKey(for: $0.speed) < Self.audioSortKey(for: $1.speed) })
                .map {
                    WordAudio(
                        id: $0.id,
                        accent: $0.accent,
                        speed: $0.speed,
                        url: URL(string: $0.audio_url) ?? URL(fileURLWithPath: "/"),
                        durationMS: $0.duration_ms ?? 0,
                        source: $0.source,
                        speakerLabel: $0.speaker_label,
                        providerReference: $0.provider_reference
                    )
                },
            supplementalDefinition: nil,
            pronunciationGuidance: pronunciation_guidance,
            languageVariant: language_variant,
            enrichmentSources: enrichment_source.map { [$0] },
            enrichmentUpdatedAt: enrichment_updated_at
        )
    }

    private static func audioSortKey(for speed: String) -> Int {
        switch speed.lowercased() {
        case "native":
            return 0
        case "slow":
            return 1
        default:
            return 2
        }
    }
}

extension UserWordProgressWithWordDTO {
    var progress: UserWordProgressDTO {
        UserWordProgressDTO(
            id: id,
            user_id: user_id,
            word_id: word_id,
            status: status,
            is_favorited: is_favorited,
            is_saved_for_review: is_saved_for_review,
            consecutive_correct: consecutive_correct,
            total_reviews: total_reviews,
            correct_reviews: correct_reviews,
            current_interval_days: current_interval_days,
            next_review_at: next_review_at,
            learned_at: learned_at,
            last_reviewed_at: last_reviewed_at
        )
    }
}

extension SavedTranslationDTO {
    func toModel() -> SavedTranslation {
        SavedTranslation(
            id: id,
            inputMode: input_mode,
            sourceText: source_text,
            translatedText: translated_text,
            sourceLanguage: source_language,
            targetLanguage: target_language,
            isSaved: is_saved,
            isFavorited: is_favorited,
            transcriptionText: transcription_text,
            extractedText: extracted_text,
            sourceImageURL: source_image_url.flatMap(URL.init(string:)),
            detectionConfidence: detection_confidence,
            sessionID: session_id,
            createdAt: created_at,
            updatedAt: updated_at
        )
    }
}

enum SupabaseFieldParser {
    private static let sqlDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static func sqlDate(from string: String) -> Date? {
        sqlDateFormatter.date(from: string)
    }

    static func sqlDateString(from date: Date) -> String {
        sqlDateFormatter.string(from: date)
    }

    static func reminderTime(from string: String?, referenceDate: Date = .now) -> Date? {
        guard let string else {
            return nil
        }

        let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }

        let timePortion = trimmed
            .split(separator: "+", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init)?
            .split(separator: ".", maxSplits: 1, omittingEmptySubsequences: true)
            .first
            .map(String.init) ?? trimmed

        let parts = timePortion.split(separator: ":")
        guard parts.count >= 2 else {
            return nil
        }

        let hour = Int(parts[0]) ?? 8
        let minute = Int(parts[1]) ?? 0
        let second = parts.count > 2 ? (Int(parts[2]) ?? 0) : 0

        return Calendar.current.date(
            bySettingHour: hour,
            minute: minute,
            second: second,
            of: referenceDate
        )
    }

    static func sqlTimeString(from date: Date?, calendar: Calendar = .current) -> String? {
        guard let date else {
            return nil
        }

        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = components.hour ?? 8
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        return String(format: "%02d:%02d:%02d", hour, minute, second)
    }

    static func defaultReminderTime(referenceDate: Date = .now) -> Date {
        Calendar.current.date(bySettingHour: 8, minute: 0, second: 0, of: referenceDate) ?? referenceDate
    }
}
