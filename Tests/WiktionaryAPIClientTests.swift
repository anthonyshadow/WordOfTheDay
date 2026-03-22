import XCTest
@testable import LinguaDaily

final class WiktionaryAPIClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testFetchEnrichmentParsesDefinitionExamplesAndPronunciation() async throws {
        let expectedDate = Date(timeIntervalSince1970: 1_720_000_000)
        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.url?.path, "/api/rest_v1/page/definition/bonjour")

            let payload = """
            {
              "French": [
                {
                  "word": "bonjour",
                  "language": "French",
                  "partOfSpeech": "interjection",
                  "definitions": [
                    {
                      "definition": "hello; good day",
                      "examples": ["Bonjour tout le monde."]
                    }
                  ],
                  "pronunciations": {
                    "text": [
                      {
                        "ipa": "/bɔ̃.ʒuʁ/",
                        "note": "Parisian"
                      }
                    ]
                  }
                }
              ]
            }
            """

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(payload.utf8)
            )
        }

        let client = WiktionaryAPIClient(
            session: MockURLProtocol.makeSession(),
            now: { expectedDate }
        )

        let enrichment = try await client.fetchEnrichment(for: "bonjour", languageCode: "fr")

        XCTAssertEqual(enrichment?.lemma, "bonjour")
        XCTAssertEqual(enrichment?.definition, "hello; good day")
        XCTAssertEqual(enrichment?.pronunciationIPA, "/bɔ̃.ʒuʁ/")
        XCTAssertEqual(enrichment?.pronunciationGuidance, "Parisian")
        XCTAssertEqual(enrichment?.usageNotes, "Pronunciation: Parisian")
        XCTAssertEqual(enrichment?.examples.map(\.sentence), ["Bonjour tout le monde."])
        XCTAssertEqual(enrichment?.sources, ["wiktionary"])
        XCTAssertEqual(enrichment?.updatedAt, expectedDate)
    }

    func testFetchEnrichmentReturnsNilForNotFound() async throws {
        MockURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 404, httpVersion: nil, headerFields: nil)!,
                Data()
            )
        }

        let client = WiktionaryAPIClient(session: MockURLProtocol.makeSession())

        let enrichment = try await client.fetchEnrichment(for: "missing-word", languageCode: "fr")

        XCTAssertNil(enrichment)
    }

    func testFetchEnrichmentThrowsDecodingErrorForUnexpectedPayload() async {
        MockURLProtocol.requestHandler = { request in
            (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(#"["invalid"]"#.utf8)
            )
        }

        let client = WiktionaryAPIClient(session: MockURLProtocol.makeSession())

        do {
            _ = try await client.fetchEnrichment(for: "bonjour", languageCode: "fr")
            XCTFail("Expected a decoding error.")
        } catch let error as AppError {
            XCTAssertEqual(error, .decoding("Wiktionary returned an unexpected payload."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
