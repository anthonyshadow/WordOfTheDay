import Foundation

protocol AudioPlayerServiceProtocol {
    func play(url: URL) async throws
    func speak(text: String, languageCode: String) async throws
}
