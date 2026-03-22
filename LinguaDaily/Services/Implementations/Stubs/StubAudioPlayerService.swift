import Foundation

final class StubAudioPlayerService: AudioPlayerServiceProtocol {
    func play(url: URL) async throws {
        #if DEBUG
        print("[Audio] play \(url.absoluteString)")
        #endif
    }

    func speak(text: String, languageCode: String) async throws {
        #if DEBUG
        print("[Audio] speak \(languageCode): \(text)")
        #endif
    }
}
