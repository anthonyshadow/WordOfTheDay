import Foundation
import XCTest
@testable import LinguaDaily

final class GoogleTextToSpeechClientTests: XCTestCase {
    override func tearDown() {
        MockURLProtocol.requestHandler = nil
        super.tearDown()
    }

    func testSynthesizePronunciationWritesAudioFileAndMarksSource() async throws {
        let tempDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        let expectedAudioData = Data("demo-audio".utf8)

        MockURLProtocol.requestHandler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertTrue(request.url?.absoluteString.contains("text:synthesize?key=test-key") == true)
            XCTAssertNotNil(request.httpBody)

            let payload = """
            {
              "audioContent": "\(expectedAudioData.base64EncodedString())"
            }
            """

            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(payload.utf8)
            )
        }

        let client = GoogleTextToSpeechClient(
            apiKey: "test-key",
            preferredVoiceName: "es-ES-Standard-A",
            session: MockURLProtocol.makeSession(),
            audioDirectory: tempDirectory
        )

        let track = try await client.synthesizePronunciation(
            for: "hola",
            languageCode: "es",
            preferredAccent: "spain"
        )

        XCTAssertEqual(track?.source, "google-tts")
        XCTAssertEqual(track?.speakerLabel, "es-ES-Standard-A")
        XCTAssertEqual(track?.providerReference, "es-ES|es-ES-Standard-A")
        XCTAssertEqual(track?.accent, "spain")
        XCTAssertTrue(track?.url.isFileURL == true)
        let storedData = try Data(contentsOf: XCTUnwrap(track?.url))
        XCTAssertEqual(storedData, expectedAudioData)
    }

    func testSynthesizePronunciationReturnsNilWhenApiKeyIsMissing() async throws {
        let client = GoogleTextToSpeechClient(
            apiKey: nil,
            preferredVoiceName: nil,
            session: MockURLProtocol.makeSession()
        )

        let track = try await client.synthesizePronunciation(
            for: "hola",
            languageCode: "es",
            preferredAccent: nil
        )

        XCTAssertNil(track)
    }

    func testSynthesizePronunciationThrowsDecodingErrorForInvalidBase64() async {
        MockURLProtocol.requestHandler = { request in
            let payload = """
            {
              "audioContent": "not-base64"
            }
            """
            return (
                HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!,
                Data(payload.utf8)
            )
        }

        let client = GoogleTextToSpeechClient(
            apiKey: "test-key",
            preferredVoiceName: nil,
            session: MockURLProtocol.makeSession(),
            audioDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
        )

        do {
            _ = try await client.synthesizePronunciation(for: "hola", languageCode: "es", preferredAccent: nil)
            XCTFail("Expected a decoding error.")
        } catch let error as AppError {
            XCTAssertEqual(error, .decoding("Google Text-to-Speech returned invalid audio data."))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }
}
