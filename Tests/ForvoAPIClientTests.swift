import XCTest
@testable import LinguaDaily

final class ForvoAPIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchPronunciationAudioMapsTracksAndPrioritizesPreferredAccent() async throws {
        MockURLProtocol.requestHandler = { request in
            XCTAssertTrue(request.url?.absoluteString.contains("/word/hola/language/es/") == true)

            let payload = """
            {
              "items": [
                {
                  "id": 11,
                  "pathmp3": "https://audio.forvo.com/es-spain.mp3",
                  "country": "Spain",
                  "username": "maria",
                  "sex": "f"
                },
                {
                  "id": 22,
                  "pathmp3": "https://audio.forvo.com/es-mexico.mp3",
                  "country": "Mexico",
                  "username": "carlos",
                  "sex": "m"
                }
              ]
            }
            """

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(payload.utf8)
            )
        }

        let client = ForvoAPIClient(apiKey: "test-key", session: MockURLProtocol.makeSession())

        let tracks = try await client.fetchPronunciationAudio(
            for: "hola",
            languageCode: "es",
            preferredAccent: "mexico"
        )

        XCTAssertEqual(tracks.count, 2)
        XCTAssertEqual(tracks.first?.url.absoluteString, "https://audio.forvo.com/es-mexico.mp3")
        XCTAssertEqual(tracks.first?.accent, "Mexico")
        XCTAssertEqual(tracks.first?.source, "forvo")
        XCTAssertEqual(tracks.first?.speakerLabel, "carlos • m")
        XCTAssertEqual(tracks.first?.providerReference, "22")
    }

    func testFetchPronunciationAudioThrowsAuthErrorOnUnauthorizedResponse() async {
        MockURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 401, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = ForvoAPIClient(apiKey: "test-key", session: MockURLProtocol.makeSession())

        do {
            _ = try await client.fetchPronunciationAudio(for: "hola", languageCode: "es", preferredAccent: nil)
            XCTFail("Expected an auth error.")
        } catch let error as AppError {
            XCTAssertEqual(error, .auth("Forvo rejected the API key."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testFetchPronunciationAudioReturnsEmptyArrayWhenApiKeyIsMissing() async throws {
        let client = ForvoAPIClient(apiKey: nil, session: MockURLProtocol.makeSession())

        let tracks = try await client.fetchPronunciationAudio(for: "hola", languageCode: "es", preferredAccent: nil)

        XCTAssertTrue(tracks.isEmpty)
    }
}
