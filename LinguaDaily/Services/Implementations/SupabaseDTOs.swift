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
    let pronunciation_ipa: String
    let part_of_speech: String
    let cefr_level: String
    let frequency_rank: Int
    let definition: String
    let usage_notes: String
}

struct ExampleSentenceDTO: Decodable {
    let id: UUID
    let word_id: UUID
    let sentence: String
    let translation: String
    let order_index: Int
}

struct WordAudioDTO: Decodable {
    let id: UUID
    let word_id: UUID
    let accent: String
    let speed: String
    let audio_url: String
    let duration_ms: Int?
}

struct DailyWordAssignmentDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let assignment_date: String
    let source: String
}

struct UserWordProgressDTO: Decodable {
    let id: UUID
    let user_id: UUID
    let word_id: UUID
    let status: String
    let is_favorited: Bool
    let is_saved_for_review: Bool
    let consecutive_correct: Int
    let total_reviews: Int
    let correct_reviews: Int
    let current_interval_days: Int
    let next_review_at: String?
}
