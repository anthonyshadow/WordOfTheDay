import Foundation

struct Word: Identifiable, Codable, Hashable, Sendable {
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
    let supplementalDefinition: String?
    let pronunciationGuidance: String?
    let languageVariant: String?
    let enrichmentSources: [String]?
    let enrichmentUpdatedAt: Date?

    init(
        id: UUID,
        languageCode: String,
        lemma: String,
        transliteration: String?,
        pronunciationIPA: String,
        partOfSpeech: String,
        cefrLevel: String,
        frequencyRank: Int,
        definition: String,
        usageNotes: String,
        examples: [ExampleSentence],
        audio: [WordAudio],
        supplementalDefinition: String? = nil,
        pronunciationGuidance: String? = nil,
        languageVariant: String? = nil,
        enrichmentSources: [String]? = nil,
        enrichmentUpdatedAt: Date? = nil
    ) {
        self.id = id
        self.languageCode = languageCode
        self.lemma = lemma
        self.transliteration = transliteration
        self.pronunciationIPA = pronunciationIPA
        self.partOfSpeech = partOfSpeech
        self.cefrLevel = cefrLevel
        self.frequencyRank = frequencyRank
        self.definition = definition
        self.usageNotes = usageNotes
        self.examples = examples
        self.audio = audio
        self.supplementalDefinition = supplementalDefinition
        self.pronunciationGuidance = pronunciationGuidance
        self.languageVariant = languageVariant
        self.enrichmentSources = enrichmentSources
        self.enrichmentUpdatedAt = enrichmentUpdatedAt
    }

    var displayPronunciation: String {
        let phoneticText: String
        if pronunciationIPA.isEmpty {
            phoneticText = pronunciationGuidance ?? ""
        } else {
            phoneticText = pronunciationIPA
        }

        if let transliteration, !phoneticText.isEmpty {
            return "\(transliteration) \(phoneticText)"
        }

        if let transliteration, phoneticText.isEmpty {
            return transliteration
        }

        return phoneticText
    }
}

struct WordAudio: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let accent: String
    let speed: String
    let url: URL
    let durationMS: Int
    let source: String?
    let speakerLabel: String?
    let providerReference: String?

    init(
        id: UUID,
        accent: String,
        speed: String,
        url: URL,
        durationMS: Int,
        source: String? = nil,
        speakerLabel: String? = nil,
        providerReference: String? = nil
    ) {
        self.id = id
        self.accent = accent
        self.speed = speed
        self.url = url
        self.durationMS = durationMS
        self.source = source
        self.speakerLabel = speakerLabel
        self.providerReference = providerReference
    }
}

struct ExampleSentence: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let sentence: String
    let translation: String
    let order: Int
    let source: String?

    init(
        id: UUID,
        sentence: String,
        translation: String,
        order: Int,
        source: String? = nil
    ) {
        self.id = id
        self.sentence = sentence
        self.translation = translation
        self.order = order
        self.source = source
    }

    var hasTranslation: Bool {
        !translation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
