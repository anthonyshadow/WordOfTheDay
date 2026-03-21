import Foundation

final class StubAudioPlayerService: AudioPlayerServiceProtocol {
    func play(url: URL) async throws {
        #if DEBUG
        print("[Audio] play \(url.absoluteString)")
        #endif
    }
}
