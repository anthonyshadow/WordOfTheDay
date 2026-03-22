import Foundation
import XCTest
@testable import LinguaDaily

final class MockURLProtocol: URLProtocol {
    static var requestHandler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        guard let handler = Self.requestHandler else {
            client?.urlProtocol(self, didFailWithError: AppError.network("No request handler configured."))
            return
        }

        do {
            let materializedRequest = Self.materializedRequest(from: request)
            let (response, data) = try handler(materializedRequest)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}

    static func makeSession() -> URLSession {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [MockURLProtocol.self]
        return URLSession(configuration: configuration)
    }

    private static func materializedRequest(from request: URLRequest) -> URLRequest {
        guard request.httpBody == nil, let bodyStream = request.httpBodyStream else {
            return request
        }

        var request = request
        request.httpBody = readAll(from: bodyStream)
        return request
    }

    private static func readAll(from stream: InputStream) -> Data {
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 1_024
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }

        while stream.hasBytesAvailable {
            let count = stream.read(buffer, maxLength: bufferSize)
            guard count > 0 else {
                break
            }
            data.append(buffer, count: count)
        }

        return data
    }
}

enum EnrichmentFixtures {
    static func word(
        languageCode: String = "fr",
        lemma: String = "bonjour",
        definition: String = "Hello",
        usageNotes: String = "Greeting",
        pronunciationIPA: String = "/bɔ̃.ʒuʁ/",
        examples: [ExampleSentence]? = nil,
        audio: [WordAudio]? = nil
    ) -> Word {
        Word(
            id: UUID(uuidString: "11111111-2222-3333-4444-555555555555")!,
            languageCode: languageCode,
            lemma: lemma,
            transliteration: nil,
            pronunciationIPA: pronunciationIPA,
            partOfSpeech: "interjection",
            cefrLevel: "A1",
            frequencyRank: 1,
            definition: definition,
            usageNotes: usageNotes,
            examples: examples ?? [
                ExampleSentence(
                    id: UUID(uuidString: "66666666-7777-8888-9999-AAAAAAAAAAAA")!,
                    sentence: "\(lemma)!",
                    translation: "Hello!",
                    order: 1
                )
            ],
            audio: audio ?? [
                WordAudio(
                    id: UUID(uuidString: "BBBBBBBB-CCCC-DDDD-EEEE-FFFFFFFFFFFF")!,
                    accent: "standard",
                    speed: "native",
                    url: URL(string: "https://example.com/\(languageCode).mp3")!,
                    durationMS: 1200
                )
            ]
        )
    }

    static func lesson(word: Word) -> DailyLesson {
        DailyLesson(
            id: UUID(uuidString: "AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE")!,
            assignmentDate: Date(timeIntervalSince1970: 1_710_000_000),
            dayNumber: 3,
            languageName: word.languageCode.uppercased(),
            word: word,
            isLearned: false,
            isFavorited: false,
            isSavedForReview: false
        )
    }
}
