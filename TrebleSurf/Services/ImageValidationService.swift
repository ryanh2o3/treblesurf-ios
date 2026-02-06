import Foundation
import Vision
import UIKit
import AVFoundation

/// Service for validating images using iOS Vision framework
class ImageValidationService {
    init() {}

    /// Validates if an image contains surf-related content using Vision framework
    /// - Parameter image: The UIImage to validate
    /// - Returns: True if the image contains surf-related content
    func validateSurfImage(_ image: UIImage) async throws -> Bool {
        guard let cgImage = image.cgImage else {
            throw ImageValidationError.invalidImage
        }

        return try await withCheckedThrowingContinuation { continuation in
            let request = VNClassifyImageRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let observations = request.results as? [VNClassificationObservation] else {
                    continuation.resume(returning: false)
                    return
                }

                let surfLabels: [String: Double] = [
                    "sea": 0.3, "ocean": 0.3, "water": 0.4, "beach": 0.3,
                    "coast": 0.3, "shore": 0.3, "wave": 0.2, "surf": 0.2,
                    "seashore": 0.3, "seacoast": 0.3, "lakeshore": 0.2,
                    "lakeside": 0.2, "waterfront": 0.3, "seaside": 0.3,
                    "coastline": 0.3, "seaboard": 0.3, "littoral": 0.2,
                    "riparian": 0.2, "aquatic": 0.2, "marine": 0.2
                ]

                let hasSurfContent = observations.contains { observation in
                    let label = observation.identifier.lowercased()
                    let confidence = observation.confidence

                    if let threshold = surfLabels[label], Float(confidence) >= Float(threshold) {
                        return true
                    }

                    for (surfLabel, threshold) in surfLabels {
                        if label.contains(surfLabel) && Float(confidence) >= Float(threshold) {
                            return true
                        }
                    }

                    return false
                }

                continuation.resume(returning: hasSurfContent)
            }

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: error)
            }
        }
    }

    /// Validates if a video contains surf-related content using Vision framework
    /// - Parameter videoURL: The URL of the video to validate
    /// - Returns: True if the video contains surf-related content
    func validateSurfVideo(_ videoURL: URL) async throws -> Bool {
        let frames = try await extractVideoFrames(from: videoURL, maxFrames: 5)
        return try await validateVideoFrames(frames)
    }

    /// Extracts frames from a video for analysis
    private func extractVideoFrames(from videoURL: URL, maxFrames: Int) async throws -> [UIImage] {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero

        let duration = try await asset.load(.duration)
        let durationSeconds = CMTimeGetSeconds(duration)
        let frameInterval = durationSeconds / Double(maxFrames)

        var timePoints: [CMTime] = []
        for i in 0..<maxFrames {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: duration.timescale)
            timePoints.append(time)
        }

        return try await withCheckedThrowingContinuation { continuation in
            var extractedFrames: [UIImage] = []
            let group = DispatchGroup()

            for timePoint in timePoints {
                group.enter()
                imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: timePoint)]) { _, cgImage, _, _, _ in
                    defer { group.leave() }
                    if let cgImage = cgImage {
                        let uiImage = UIImage(cgImage: cgImage)
                        extractedFrames.append(uiImage)
                    }
                }
            }

            group.notify(queue: .main) {
                if extractedFrames.isEmpty {
                    continuation.resume(throwing: ImageValidationError.noFramesExtracted)
                } else {
                    continuation.resume(returning: extractedFrames)
                }
            }
        }
    }

    /// Validates multiple video frames
    private func validateVideoFrames(_ frames: [UIImage]) async throws -> Bool {
        var validFrameCount = 0

        for frame in frames {
            let isValid = try await validateSurfImage(frame)
            if isValid {
                validFrameCount += 1
            }
        }

        // Consider video valid if at least 30% of frames are valid
        let validationThreshold = max(1, Int(Double(frames.count) * 0.3))
        return validFrameCount >= validationThreshold
    }
}

// MARK: - Error Types
enum ImageValidationError: Error, LocalizedError {
    case invalidImage
    case noFramesExtracted
    case validationFailed

    var errorDescription: String? {
        switch self {
        case .invalidImage:
            return "Invalid image provided for validation"
        case .noFramesExtracted:
            return "Could not extract frames from video for validation"
        case .validationFailed:
            return "Image validation failed"
        }
    }
}
