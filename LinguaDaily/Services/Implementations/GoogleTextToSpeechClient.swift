import CryptoKit
import Foundation

protocol GoogleTextToSpeechClientProtocol {
    func synthesizePronunciation(
        for lemma: String,
        languageCode: String,
        preferredAccent: String?
    ) async throws -> WordAudio?
}

final class GoogleTextToSpeechClient: GoogleTextToSpeechClientProtocol {
    private let apiKey: String?
    private let preferredVoiceName: String?
    private let session: URLSession
    private let fileManager: FileManager
    private let audioDirectory: URL

    init(
        apiKey: String?,
        preferredVoiceName: String?,
        session: URLSession = .linguaDailyExternalAPISession(),
        fileManager: FileManager = .default,
        audioDirectory: URL? = nil
    ) {
        self.apiKey = apiKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.preferredVoiceName = preferredVoiceName?.trimmingCharacters(in: .whitespacesAndNewlines)
        self.session = session
        self.fileManager = fileManager
        self.audioDirectory = audioDirectory ?? fileManager.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("LinguaDailyAudio", isDirectory: true)
    }

    func synthesizePronunciation(
        for lemma: String,
        languageCode: String,
        preferredAccent: String?
    ) async throws -> WordAudio? {
        guard let apiKey, apiKey.isEmpty == false else {
            return nil
        }

        let trimmedLemma = lemma.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedLemma.isEmpty == false else {
            return nil
        }

        let voice = Self.voiceSelection(
            for: languageCode,
            preferredAccent: preferredAccent,
            preferredVoiceName: preferredVoiceName
        )

        let requestBody = SynthesizeSpeechRequest(
            input: .init(text: trimmedLemma),
            voice: .init(languageCode: voice.languageCode, name: voice.name),
            audioConfig: .init(audioEncoding: "MP3", speakingRate: 1.0)
        )

        var components = URLComponents(string: "https://texttospeech.googleapis.com/v1/text:synthesize")
        components?.queryItems = [URLQueryItem(name: "key", value: apiKey)]
        guard let url = components?.url else {
            throw AppError.validation("The Google Text-to-Speech URL is invalid.")
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(requestBody)

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw AppError.network("Google Text-to-Speech returned an invalid response.")
        }

        guard (200...299).contains(httpResponse.statusCode) else {
            throw AppError.network("Google Text-to-Speech failed with status \(httpResponse.statusCode).")
        }

        let payload = try JSONDecoder().decode(SynthesizeSpeechResponse.self, from: data)
        guard let audioData = Data(base64Encoded: payload.audioContent) else {
            throw AppError.decoding("Google Text-to-Speech returned invalid audio data.")
        }

        let fileURL = try writeAudioData(audioData, fileName: Self.fileName(
            lemma: trimmedLemma,
            languageCode: voice.languageCode,
            voiceName: voice.name
        ))

        return WordAudio(
            id: UUID(),
            accent: preferredAccent?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty(voice.regionLabel) ?? voice.regionLabel,
            speed: "native",
            url: fileURL,
            durationMS: 0,
            source: "google-tts",
            speakerLabel: voice.name ?? "Google Cloud TTS",
            providerReference: voice.reference
        )
    }

    private func writeAudioData(_ audioData: Data, fileName: String) throws -> URL {
        try fileManager.createDirectory(at: audioDirectory, withIntermediateDirectories: true, attributes: nil)
        let fileURL = audioDirectory.appendingPathComponent(fileName)
        try audioData.write(to: fileURL, options: .atomic)
        return fileURL
    }

    private static func fileName(lemma: String, languageCode: String, voiceName: String?) -> String {
        let cacheKey = "\(WordNormalizer.normalizeLemma(lemma))|\(languageCode)|\(voiceName ?? "default")"
        let digest = SHA256.hash(data: Data(cacheKey.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return "google-tts-\(hash).mp3"
    }

    private static func voiceSelection(
        for languageCode: String,
        preferredAccent: String?,
        preferredVoiceName: String?
    ) -> VoiceSelection {
        if let preferredVoiceName, preferredVoiceName.isEmpty == false {
            return VoiceSelection(
                languageCode: resolvedGoogleLanguageCode(languageCode, preferredAccent: preferredAccent),
                name: preferredVoiceName,
                regionLabel: preferredAccent?.trimmingCharacters(in: .whitespacesAndNewlines).ifEmpty("standard") ?? "standard"
            )
        }

        let resolvedLanguageCode = resolvedGoogleLanguageCode(languageCode, preferredAccent: preferredAccent)
        let regionLabel = resolvedLanguageCode
            .split(separator: "-")
            .dropFirst()
            .first
            .map { $0.lowercased() } ?? "standard"

        return VoiceSelection(
            languageCode: resolvedLanguageCode,
            name: nil,
            regionLabel: regionLabel
        )
    }

    private static func resolvedGoogleLanguageCode(_ languageCode: String, preferredAccent: String?) -> String {
        let baseLanguageCode = WordNormalizer.baseLanguageCode(from: languageCode)
        let preferredAccent = preferredAccent?.lowercased() ?? ""

        switch baseLanguageCode {
        case "de":
            return "de-DE"
        case "en":
            return preferredAccent.contains("uk") || preferredAccent.contains("brit") ? "en-GB" : "en-US"
        case "es":
            return preferredAccent.contains("mex") ? "es-MX" : "es-ES"
        case "fr":
            return "fr-FR"
        case "it":
            return "it-IT"
        case "ja":
            return "ja-JP"
        case "ko":
            return "ko-KR"
        case "pt":
            return preferredAccent.contains("portugal") ? "pt-PT" : "pt-BR"
        case "zh":
            return "cmn-CN"
        default:
            return languageCode.replacingOccurrences(of: "_", with: "-")
        }
    }
}

private struct SynthesizeSpeechRequest: Encodable {
    let input: Input
    let voice: Voice
    let audioConfig: AudioConfig

    struct Input: Encodable {
        let text: String
    }

    struct Voice: Encodable {
        let languageCode: String
        let name: String?
    }

    struct AudioConfig: Encodable {
        let audioEncoding: String
        let speakingRate: Double
    }
}

private struct SynthesizeSpeechResponse: Decodable {
    let audioContent: String
}

private struct VoiceSelection {
    let languageCode: String
    let name: String?
    let regionLabel: String

    var reference: String {
        [languageCode, name].compactMap { $0 }.joined(separator: "|")
    }
}
