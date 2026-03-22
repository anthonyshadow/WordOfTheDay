import Foundation

protocol ForvoAPIClientProtocol {
    func fetchPronunciationAudio(
        for lemma: String,
        languageCode: String,
        preferredAccent: String?
    ) async throws -> [WordAudio]
}

final class ForvoAPIClient: ForvoAPIClientProtocol {
    private let apiKey: String?
    private let session: URLSession

    init(
        apiKey: String?,
        session: URLSession = .linguaDailyExternalAPISession()
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
    }

    func fetchPronunciationAudio(
        for lemma: String,
        languageCode: String,
        preferredAccent: String?
    ) async throws -> [WordAudio] {
        guard let apiKey, apiKey.isEmpty == false else {
            return []
        }

        let trimmedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLemma.isEmpty == false else {
            return []
        }

        let encodedLemma = trimmedLemma.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? trimmedLemma
        let encodedLanguage = WordNormalizer.baseLanguageCode(from: languageCode)
            .addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? languageCode

        guard let url = URL(string:
            "https://apifree.forvo.com/key/\(apiKey)/format/json/action/standard-pronunciation/word/\(encodedLemma)/language/\(encodedLanguage)/order/rate-desc/limit/3"
        ) else {
            throw AppError.validation("The Forvo lookup URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("Forvo returned an invalid response.")
        }

        switch httpResponse.statusCode {
        case 200...299:
            return try Self.parseAudio(data: data, preferredAccent: preferredAccent)
        case 401:
            throw AppError.auth("Forvo rejected the API key.")
        case 404:
            return []
        default:
            throw AppError.network("Forvo request failed with status \(httpResponse.statusCode).")
        }
    }

    private static func parseAudio(data: Data, preferredAccent: String?) throws -> [WordAudio] {
        let jsonObject = try JSONSerialization.jsonObject(with: data)
        guard let root = jsonObject as? [String: Any] else {
            throw AppError.decoding("Forvo returned an unexpected payload.")
        }

        guard let items = root["items"] as? [[String: Any]] else {
            return []
        }

        let preferredAccent = preferredAccent?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let sortedItems = items.sorted { lhs, rhs in
            let lhsScore = sortScore(for: lhs, preferredAccent: preferredAccent)
            let rhsScore = sortScore(for: rhs, preferredAccent: preferredAccent)
            if lhsScore != rhsScore {
                return lhsScore > rhsScore
            }
            let lhsLabel = stringValue(in: lhs, keys: ["country", "accent", "username"]) ?? ""
            let rhsLabel = stringValue(in: rhs, keys: ["country", "accent", "username"]) ?? ""
            return lhsLabel < rhsLabel
        }

        return sortedItems.compactMap { item in
            guard let rawURL = stringValue(in: item, keys: ["pathmp3", "pathogg"]),
                  let url = URL(string: rawURL) else {
                return nil
            }

            let accent = (stringValue(in: item, keys: ["country", "accent"]) ?? "standard").ifEmpty("standard")
            let speakerMetadata = [
                stringValue(in: item, keys: ["username"]),
                stringValue(in: item, keys: ["sex"])
            ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { $0.isEmpty == false }
            .joined(separator: " • ")

            return WordAudio(
                id: UUID(),
                accent: accent,
                speed: "native",
                url: url,
                durationMS: 0,
                source: "forvo",
                speakerLabel: speakerMetadata.isEmpty ? nil : speakerMetadata,
                providerReference: stringValue(in: item, keys: ["id"])
            )
        }
    }

    private static func sortScore(for item: [String: Any], preferredAccent: String?) -> Int {
        guard let preferredAccent, preferredAccent.isEmpty == false else {
            return 0
        }

        let accentCandidates = [
            stringValue(in: item, keys: ["country"]),
            stringValue(in: item, keys: ["accent"])
        ]
        .compactMap { $0?.lowercased() }

        if accentCandidates.contains(where: { $0.contains(preferredAccent) }) {
            return 2
        }

        if let speaker = stringValue(in: item, keys: ["username"])?.lowercased(),
           speaker.contains(preferredAccent) {
            return 1
        }

        return 0
    }

    private static func stringValue(in item: [String: Any], keys: [String]) -> String? {
        for key in keys {
            if let value = item[key] as? String {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if trimmedValue.isEmpty == false {
                    return trimmedValue
                }
            } else if let value = item[key] as? Int {
                return String(value)
            }
        }
        return nil
    }
}
