import Foundation

struct Word: Identifiable, Codable, Hashable {
    let id: UUID
    let languageCode: String
    let lemma: String
    let transliteration: String?
    let pronunciationIPA: String
    let partOfSpeech: String
    let cefrLevel: String
    let frequencyRank: Int
    let definition: String
    let usageNotes: String
    let examples: [ExampleSentence]
    let audio: [WordAudio]

    var displayPronunciation: String {
        if let transliteration {
            return "\(transliteration) \(pronunciationIPA)"
        }
        return pronunciationIPA
    }
}

struct WordAudio: Identifiable, Codable, Hashable {
    let id: UUID
    let accent: String
    let speed: String
    let url: URL
    let durationMS: Int
}

struct ExampleSentence: Identifiable, Codable, Hashable {
    let id: UUID
    let sentence: String
    let translation: String
    let order: Int
}
