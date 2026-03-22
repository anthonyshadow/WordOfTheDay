import Foundation

protocol WiktionaryAPIClientProtocol {
    func fetchEnrichment(for lemma: String, languageCode: String) async throws -> WordEnrichmentSnapshot?
}

final class WiktionaryAPIClient: WiktionaryAPIClientProtocol {
    private let session: URLSession
    private let now: @Sendable () -> Date
    private let baseURL = URL(string: "https://en.wiktionary.org/api/rest_v1/page/definition")!

    init(
        session: URLSession = .linguaDailyExternalAPISession(),
        now: @escaping @Sendable () -> Date = { .now }
    ) {
        self.session = session
        self.now = now
    }

    func fetchEnrichment(for lemma: String, languageCode: String) async throws -> WordEnrichmentSnapshot? {
        let trimmedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLemma.isEmpty == false else {
            return nil
        }

        var request = URLRequest(url: baseURL.appendingPathComponent(trimmedLemma))
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("Wiktionary returned an invalid response.")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try Self.parse(data: data, lemma: trimmedLemma, languageCode: languageCode, updatedAt: now())
        case 404:
            return nil
        default:
            throw AppError.network("Wiktionary request failed with status \(httpResponse.statusCode).")
        }
    }

    private static func parse(
        data: Data,
        lemma: String,
        languageCode: String,
        updatedAt: Date
    ) throws -> WordEnrichmentSnapshot? {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let root = jsonObject as? [String: Any] else {
            throw AppError.decoding("Wiktionary returned an unexpected payload.")
        }

        let requestedLanguageName = Self.languageName(for: languageCode)
        let requestedBaseCode = WordNormalizer.baseLanguageCode(from: languageCode)
        let candidateEntries = Self.entryDictionaries(
            from: root,
            requestedLanguageName: requestedLanguageName,
            requestedBaseCode: requestedBaseCode
        )

        guard let entry = candidateEntries.first(where: { Self.definitionText(from: $0) != nil || Self.pronunciationText(from: $0) != nil }) ?? candidateEntries.first else {
            return nil
        }

        let examples = Self.examples(from: entry)
        let pronunciationGuidance = Self.pronunciationText(from: entry)
        let languageVariant = Self.variantText(from: entry, requestedLanguageName: requestedLanguageName)
        let usageNotes = Self.usageNotes(
            pronunciationGuidance: pronunciationGuidance,
            languageVariant: languageVariant
        )

        return WordEnrichmentSnapshot(
            lemma: Self.entryLemma(from: entry) ?? lemma,
            transliteration: Self.transliteration(from: entry),
            pronunciationIPA: Self.ipaText(from: entry),
            partOfSpeech: Self.string(in: entry, keys: ["partOfSpeech", "part_of_speech"]),
            definition: Self.definitionText(from: entry),
            supplementalDefinition: nil,
            usageNotes: usageNotes,
            examples: examples.enumerated().map { index, sentence in
                ExampleSentence(
                    id: UUID(),
                    sentence: sentence,
                    translation: "",
                    order: index + 1,
                    source: "wiktionary"
                )
            },
            audio: [],
            pronunciationGuidance: pronunciationGuidance,
            languageVariant: languageVariant,
            sources: ["wiktionary"],
            updatedAt: updatedAt
        )
    }

    private static func entryDictionaries(
        from root: [String: Any],
        requestedLanguageName: String?,
        requestedBaseCode: String
    ) -> [[String: Any]] {
        let normalizedRequestedLanguageName = requestedLanguageName?.lowercased()
        let directMatches = root.compactMap { key, value -> [[String: Any]]? in
            let normalizedKey = key.lowercased()
            let matchesLanguageName = normalizedRequestedLanguageName.map { normalizedKey == $0 } ?? false
            let matchesBaseCode = WordNormalizer.baseLanguageCode(from: key) == requestedBaseCode
            guard matchesLanguageName || matchesBaseCode else {
                return nil
            }
            return value as? [[String: Any]]
        }

        if let firstDirectMatch = directMatches.first, firstDirectMatch.isEmpty == false {
            return firstDirectMatch
        }

        return root.values.compactMap { $0 as? [[String: Any]] }.flatMap { $0 }
    }

    private static func definitionText(from entry: [String: Any]) -> String? {
        guard let definitions = entry["definitions"] as? [[String: Any]] else {
            return nil
        }

        for item in definitions {
            if let definition = string(in: item, keys: ["definition", "text", "gloss"]), definition.isEmpty == false {
                return definition
            }
        }

        return nil
    }

    private static func examples(from entry: [String: Any]) -> [String] {
        guard let definitions = entry["definitions"] as? [[String: Any]] else {
            return []
        }

        var results: [String] = []
        for item in definitions {
            if let exampleStrings = item["examples"] as? [String] {
                results.append(contentsOf: exampleStrings)
            } else if let exampleObjects = item["examples"] as? [[String: Any]] {
                results.append(contentsOf: exampleObjects.compactMap { string(in: $0, keys: ["text", "example"]) })
            }
        }

        return results.reduce(into: [String]()) { result, sentence in
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedSentence.isEmpty == false else {
                return
            }
            guard result.contains(where: { $0.caseInsensitiveCompare(trimmedSentence) == .orderedSame }) == false else {
                return
            }
            result.append(trimmedSentence)
        }
        .prefix(3)
        .map { $0 }
    }

    private static func ipaText(from entry: [String: Any]) -> String? {
        if let pronunciations = entry["pronunciations"] as? [String: Any] {
            if let textEntries = pronunciations["text"] as? [[String: Any]] {
                for item in textEntries {
                    if let ipa = string(in: item, keys: ["ipa", "IPA"]), ipa.isEmpty == false {
                        return ipa
                    }
                }
            }

            if let ipa = string(in: pronunciations, keys: ["ipa", "IPA"]), ipa.isEmpty == false {
                return ipa
            }
        }

        return nil
    }

    private static func pronunciationText(from entry: [String: Any]) -> String? {
        if let pronunciations = entry["pronunciations"] as? [String: Any] {
            if let textEntries = pronunciations["text"] as? [[String: Any]] {
                for item in textEntries {
                    if let note = string(in: item, keys: ["text", "note", "tags"]), note.isEmpty == false {
                        return note
                    }
                }
            }

            if let text = string(in: pronunciations, keys: ["text", "note"]), text.isEmpty == false {
                return text
            }
        }

        return nil
    }

    private static func transliteration(from entry: [String: Any]) -> String? {
        string(in: entry, keys: ["transliteration", "roman"])
    }

    private static func entryLemma(from entry: [String: Any]) -> String? {
        string(in: entry, keys: ["word", "title", "lemma"])
    }

    private static func variantText(from entry: [String: Any], requestedLanguageName: String?) -> String? {
        if let language = string(in: entry, keys: ["language", "lang"]), language.isEmpty == false {
            if let requestedLanguageName, language.caseInsensitiveCompare(requestedLanguageName) == .orderedSame {
                return nil
            }
            return language
        }

        if let pronunciations = entry["pronunciations"] as? [String: Any],
           let textEntries = pronunciations["text"] as? [[String: Any]] {
            for item in textEntries {
                if let tags = string(in: item, keys: ["tags", "tag", "note"]), tags.isEmpty == false {
                    return tags
                }
            }
        }

        return nil
    }

    private static func usageNotes(pronunciationGuidance: String?, languageVariant: String?) -> String? {
        let entries = [
            pronunciationGuidance.map { "Pronunciation: \($0)" },
            languageVariant.map { "Variant: \($0)" }
        ]
        .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { $0.isEmpty == false }

        guard entries.isEmpty == false else {
            return nil
        }

        return entries.joined(separator: "\n\n")
    }

    private static func string(in dictionary: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = dictionary[key] as? String {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedValue.isEmpty == false {
                    return trimmedValue
                }
            } else if let values = dictionary[key] as? [String], let first = values.first {
                let trimmedValue = first.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedValue.isEmpty == false {
                    return trimmedValue
                }
            }
        }

        return nil
    }

    private static func languageName(for languageCode: String) -> String? {
        Locale(identifier: "en_US_POSIX")
            .localizedString(forLanguageCode: WordNormalizer.baseLanguageCode(from: languageCode))
    }
}
