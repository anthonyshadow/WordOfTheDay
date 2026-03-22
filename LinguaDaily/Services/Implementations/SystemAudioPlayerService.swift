import AVFoundation
import Foundation

final class SystemAudioPlayerService: AudioPlayerServiceProtocol {
    private var activePlayer: AVPlayer?
    private let speechSynthesizer = AVSpeechSynthesizer()

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

    func speak(text: String, languageCode: String) async throws {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            throw AppError.validation("There is no pronunciation text to play.")
        }

        do {
            try configureAudioSession()
        } catch {
            throw AppError.unknown("The audio session could not be started.")
        }

        await MainActor.run {
            let utterance = AVSpeechUtterance(string: trimmedText)
            utterance.voice = AVSpeechSynthesisVoice(language: Self.voiceIdentifier(for: languageCode))
            utterance.rate = AVSpeechUtteranceDefaultSpeechRate
            if speechSynthesizer.isSpeaking {
                speechSynthesizer.stopSpeaking(at: .immediate)
            }
            speechSynthesizer.speak(utterance)
        }
    }

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()
        try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
        try session.setActive(true)
    }

    private static func voiceIdentifier(for languageCode: String) -> String {
        switch languageCode.lowercased() {
        case "de":
            return "de-DE"
        case "es":
            return "es-ES"
        case "fr":
            return "fr-FR"
        case "it":
            return "it-IT"
        case "ja":
            return "ja-JP"
        case "ko":
            return "ko-KR"
        case "zh":
            return "zh-CN"
        default:
            return languageCode
        }
    }
}
