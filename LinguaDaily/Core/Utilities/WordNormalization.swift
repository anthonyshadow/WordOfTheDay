import Foundation

enum WordNormalizer {
    static func normalizeLemma(_ lemma: String) -> String {
        let standardizedApostrophes = lemma.replacingOccurrences(of: "’", with: "'")
        let collapsedWhitespace = standardizedApostrophes.replacingOccurrences(
            of: "\\s+",
            with: " ",
            options: .regularExpression
        )
        return collapsedWhitespace
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }

    static func baseLanguageCode(from languageCode: String) -> String {
        let normalized = languageCode
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "_", with: "-")
            .lowercased()
        return normalized.split(separator: "-").first.map(String.init) ?? normalized
    }
}
