import AVFoundation
import Foundation
import ImageIO
import NaturalLanguage
import UIKit
import Vision

enum CameraTranslationPermissionState: Equatable {
    case authorized
    case denied
    case unavailable
}

struct CameraOCRResult: Equatable {
    let extractedText: String
    let detectedLanguageCode: String?
    let detectionConfidence: Double?
}

protocol CameraTranslationProviding {
    var isCameraAvailable: Bool { get }
    func requestPermissionIfNeeded() async -> CameraTranslationPermissionState
    func extractText(from image: UIImage, preferredLocaleIdentifier: String?) async throws -> CameraOCRResult
}

enum CameraTranslationError: Error {
    case permissionDenied
    case cameraUnavailable
    case imageProcessingFailed
    case noTextDetected
}

struct SystemCameraTranslationProvider: CameraTranslationProviding {
    var isCameraAvailable: Bool {
        UIImagePickerController.isSourceTypeAvailable(.camera)
    }

    func requestPermissionIfNeeded() async -> CameraTranslationPermissionState {
        guard isCameraAvailable else {
            return .unavailable
        }

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            return .authorized
        case .denied, .restricted:
            return .denied
        case .notDetermined:
            let granted = await withCheckedContinuation { continuation in
                AVCaptureDevice.requestAccess(for: .video) { granted in
                    continuation.resume(returning: granted)
                }
            }
            return granted ? .authorized : .denied
        @unknown default:
            return .unavailable
        }
    }

    func extractText(from image: UIImage, preferredLocaleIdentifier: String?) async throws -> CameraOCRResult {
        let request = VNRecognizeTextRequest()
        request.recognitionLevel = .accurate
        request.usesLanguageCorrection = true

        if let preferredLocaleIdentifier,
           !preferredLocaleIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            request.recognitionLanguages = [preferredLocaleIdentifier]
        }

        let handler: VNImageRequestHandler
        if let cgImage = image.cgImage {
            handler = VNImageRequestHandler(
                cgImage: cgImage,
                orientation: image.cgImagePropertyOrientation,
                options: [:]
            )
        } else if let ciImage = CIImage(image: image) {
            handler = VNImageRequestHandler(
                ciImage: ciImage,
                orientation: image.cgImagePropertyOrientation,
                options: [:]
            )
        } else {
            throw CameraTranslationError.imageProcessingFailed
        }

        do {
            try handler.perform([request])
        } catch {
            throw CameraTranslationError.imageProcessingFailed
        }

        let extractedLines = request.results?
            .compactMap { observation in
                observation.topCandidates(1).first?.string.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty } ?? []

        let extractedText = extractedLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !extractedText.isEmpty else {
            throw CameraTranslationError.noTextDetected
        }

        let detection = Self.detectLanguage(for: extractedText)
        return CameraOCRResult(
            extractedText: extractedText,
            detectedLanguageCode: detection.languageCode,
            detectionConfidence: detection.confidence
        )
    }

    private static func detectLanguage(for text: String) -> (languageCode: String?, confidence: Double?) {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedText.isEmpty else {
            return (nil, nil)
        }

        let recognizer = NLLanguageRecognizer()
        recognizer.processString(trimmedText)
        let hypotheses = recognizer.languageHypotheses(withMaximum: 1)
        guard let detectedLanguage = hypotheses.first else {
            return (nil, nil)
        }

        return (detectedLanguage.key.rawValue, detectedLanguage.value)
    }
}

private extension UIImage {
    var cgImagePropertyOrientation: CGImagePropertyOrientation {
        switch imageOrientation {
        case .up:
            return .up
        case .upMirrored:
            return .upMirrored
        case .down:
            return .down
        case .downMirrored:
            return .downMirrored
        case .left:
            return .left
        case .leftMirrored:
            return .leftMirrored
        case .right:
            return .right
        case .rightMirrored:
            return .rightMirrored
        @unknown default:
            return .up
        }
    }
}
