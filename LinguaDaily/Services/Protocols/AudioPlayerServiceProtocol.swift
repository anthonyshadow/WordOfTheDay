import Foundation

protocol AudioPlayerServiceProtocol {
    func play(url: URL) async throws
}
