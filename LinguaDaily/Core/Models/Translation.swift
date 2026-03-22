import Foundation

enum TranslationInputMode: String, Codable, CaseIterable, Hashable {
    case text
    case voice
    case camera

    var title: String {
        switch self {
        case .text:
            return "Text"
        case .voice:
            return "Voice"
        case .camera:
            return "Camera"
        }
    }
}

enum TranslationLibraryFilter: String, CaseIterable, Hashable {
    case all
    case favorites

    var title: String {
        switch self {
        case .all:
            return "All"
        case .favorites:
            return "Favorites"
        }
    }
}

enum TranslationSourceSelection: Hashable {
    case autoDetect
    case manual(Language)

    var title: String {
        switch self {
        case .autoDetect:
            return "Auto-detect"
        case let .manual(language):
            return language.name
        }
    }

    var language: Language? {
        switch self {
        case .autoDetect:
            return nil
        case let .manual(language):
            return language
        }
    }

    var languageCode: String? {
        language?.code
    }
}

struct TranslationDraft: Hashable {
    let inputMode: TranslationInputMode
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let transcriptionText: String?
    let extractedText: String?
    let sourceImageURL: URL?
    let detectionConfidence: Double?
    let sessionID: String?
}

struct SavedTranslation: Identifiable, Codable, Hashable {
    let id: UUID
    let inputMode: TranslationInputMode
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    let isSaved: Bool
    let isFavorited: Bool
    let transcriptionText: String?
    let extractedText: String?
    let sourceImageURL: URL?
    let detectionConfidence: Double?
    let sessionID: String?
    let createdAt: Date
    let updatedAt: Date

    var sourceLanguageName: String {
        TranslationLanguageFormatter.displayName(for: sourceLanguage)
    }

    var targetLanguageName: String {
        TranslationLanguageFormatter.displayName(for: targetLanguage)
    }

    var languagePairLabel: String {
        "\(sourceLanguageName) -> \(targetLanguageName)"
    }

    var shareText: String {
        """
        \(sourceText)

        \(translatedText)

        \(languagePairLabel)
        """
    }
}

struct TextTranslationResult: Identifiable, Hashable {
    let id: UUID
    let sourceText: String
    let translatedText: String
    let sourceLanguage: String
    let targetLanguage: String
    var savedTranslationID: UUID?
    var isFavorited: Bool
    let sessionID: String?

    init(
        id: UUID = UUID(),
        sourceText: String,
        translatedText: String,
        sourceLanguage: String,
        targetLanguage: String,
        savedTranslationID: UUID? = nil,
        isFavorited: Bool = false,
        sessionID: String? = nil
    ) {
        self.id = id
        self.sourceText = sourceText
        self.translatedText = translatedText
        self.sourceLanguage = sourceLanguage
        self.targetLanguage = targetLanguage
        self.savedTranslationID = savedTranslationID
        self.isFavorited = isFavorited
        self.sessionID = sessionID
    }

    var isSaved: Bool {
        savedTranslationID != nil
    }

    var sourceLanguageName: String {
        TranslationLanguageFormatter.displayName(for: sourceLanguage)
    }

    var targetLanguageName: String {
        TranslationLanguageFormatter.displayName(for: targetLanguage)
    }

    var languagePairLabel: String {
        "\(sourceLanguageName) -> \(targetLanguageName)"
    }

    var shareText: String {
        """
        \(sourceText)

        \(translatedText)

        \(languagePairLabel)
        """
    }

    var draft: TranslationDraft {
        TranslationDraft(
            inputMode: .text,
            sourceText: sourceText,
            translatedText: translatedText,
            sourceLanguage: sourceLanguage,
            targetLanguage: targetLanguage,
            transcriptionText: nil,
            extractedText: nil,
            sourceImageURL: nil,
            detectionConfidence: nil,
            sessionID: sessionID
        )
    }

    init(savedTranslation: SavedTranslation) {
        self.init(
            id: savedTranslation.id,
            sourceText: savedTranslation.sourceText,
            translatedText: savedTranslation.translatedText,
            sourceLanguage: savedTranslation.sourceLanguage,
            targetLanguage: savedTranslation.targetLanguage,
            savedTranslationID: savedTranslation.id,
            isFavorited: savedTranslation.isFavorited,
            sessionID: savedTranslation.sessionID
        )
    }
}

enum TranslationLanguageFormatter {
    static func displayName(for identifier: String, locale: Locale = .current) -> String {
        let trimmed = identifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return "Unknown"
        }

        let normalizedIdentifier = trimmed.replacingOccurrences(of: "_", with: "-")
        if let localizedIdentifier = locale.localizedString(forIdentifier: normalizedIdentifier),
           !localizedIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedIdentifier
        }

        let minimalIdentifier = Locale.Language(identifier: normalizedIdentifier).minimalIdentifier
        if let localizedLanguage = locale.localizedString(forLanguageCode: minimalIdentifier),
           !localizedLanguage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return localizedLanguage
        }

        return normalizedIdentifier.uppercased()
    }
}
