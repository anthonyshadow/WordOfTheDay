import AVFoundation
import Foundation

final class SystemAudioPlayerService: AudioPlayerServiceProtocol {
    private var activePlayer: AVPlayer?

    func play(url: URL) async throws {
        let asset = AVURLAsset(url: url)

        do {
            let isPlayable = try await asset.load(.isPlayable)
            guard isPlayable else {
                throw AppError.network("Pronunciation audio is not available right now.")
            }
        } catch let error as AppError {
            throw error
        } catch {
            throw AppError.network("Pronunciation audio could not be loaded.")
        }

        do {
            try configureAudioSession()
        } catch {
            throw AppError.unknown("The audio session could not be started.")
        }

        await MainActor.run {
            let playerItem = AVPlayerItem(asset: asset)
            let player = AVPlayer(playerItem: playerItem)
            player.automaticallyWaitsToMinimizeStalling = true
            self.activePlayer = player
            player.play()
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }
}
