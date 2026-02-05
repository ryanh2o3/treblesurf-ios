import Foundation
import Vision
import UIKit
import AVFoundation

/// Service for validating images using iOS Vision framework
class ImageValidationService {
    static let shared = ImageValidationService()
    
    init() {}
    
    /// Validates if an image contains surf-related content using Vision framework
    /// - Parameters:
    ///   - image: The UIImage to validate
    ///   - completion: Completion handler with validation result
    func validateSurfImage(_ image: UIImage, completion: @escaping (Result<Bool, Error>) -> Void) {
        guard let cgImage = image.cgImage else {
            completion(.failure(ImageValidationError.invalidImage))
            return
        }
        
        // Create a request to detect objects in the image
        let request = VNClassifyImageRequest { request, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            
            guard let observations = request.results as? [VNClassificationObservation] else {
                completion(.success(false))
                return
            }
            
            // Define surf-related labels with their confidence thresholds
            let surfLabels = [
                "sea": 0.3,
                "ocean": 0.3,
                "water": 0.4,
                "beach": 0.3,
                "coast": 0.3,
                "shore": 0.3,
                "wave": 0.2,
                "surf": 0.2,
                "seashore": 0.3,
                "seacoast": 0.3,
                "lakeshore": 0.2,
                "lakeside": 0.2,
                "waterfront": 0.3,
                "seaside": 0.3,
                "coastline": 0.3,
                "seaboard": 0.3,
                "littoral": 0.2,
                "riparian": 0.2,
                "aquatic": 0.2,
                "marine": 0.2
            ]
            
            // Check if any surf-related labels meet the confidence threshold
            let hasSurfContent = observations.contains { observation in
                let label = observation.identifier.lowercased()
                let confidence = observation.confidence
                
                // Check for exact matches
                if let threshold = surfLabels[label], Float(confidence) >= Float(threshold) {
                    return true
                }
                
                // Check for partial matches (e.g., "sea waves", "ocean water")
                for (surfLabel, threshold) in surfLabels {
                    if label.contains(surfLabel) && Float(confidence) >= Float(threshold) {
                        return true
                    }
                }
                
                return false
            }
            
            completion(.success(hasSurfContent))
        }
        
        // Perform the request
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        do {
            try handler.perform([request])
        } catch {
            completion(.failure(error))
        }
    }
    
    /// Validates if a video contains surf-related content using Vision framework
    /// - Parameters:
    ///   - videoURL: The URL of the video to validate
    ///   - completion: Completion handler with validation result
    func validateSurfVideo(_ videoURL: URL, completion: @escaping (Result<Bool, Error>) -> Void) {
        // Extract frames from video for analysis
        extractVideoFrames(from: videoURL, maxFrames: 5) { result in
            switch result {
            case .success(let frames):
                self.validateVideoFrames(frames, completion: completion)
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    /// Extracts frames from a video for analysis
    private func extractVideoFrames(from videoURL: URL, maxFrames: Int, completion: @escaping (Result<[UIImage], Error>) -> Void) {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.requestedTimeToleranceAfter = .zero
        imageGenerator.requestedTimeToleranceBefore = .zero
        
        // Calculate time points to sample
        Task {
            do {
                let duration = try await asset.load(.duration)
                let durationSeconds = CMTimeGetSeconds(duration)
                await self.extractFrames(from: imageGenerator, duration: duration, durationSeconds: durationSeconds, maxFrames: maxFrames, completion: completion)
            } catch {
                completion(.failure(error))
            }
        }
    }
    
    /// Helper method to extract frames after loading duration
    private func extractFrames(from imageGenerator: AVAssetImageGenerator, duration: CMTime, durationSeconds: Double, maxFrames: Int, completion: @escaping (Result<[UIImage], Error>) -> Void) async {
        let frameInterval = durationSeconds / Double(maxFrames)
        
        var timePoints: [CMTime] = []
        for i in 0..<maxFrames {
            let time = CMTime(seconds: Double(i) * frameInterval, preferredTimescale: duration.timescale)
            timePoints.append(time)
        }
        
        var extractedFrames: [UIImage] = []
        let group = DispatchGroup()
        
        for timePoint in timePoints {
            group.enter()
            imageGenerator.generateCGImagesAsynchronously(forTimes: [NSValue(time: timePoint)]) { _, cgImage, _, result, error in
                defer { group.leave() }
                
                if let error = error {
                    print("Error extracting frame: \(error)")
                    return
                }
                
                if let cgImage = cgImage {
                    let uiImage = UIImage(cgImage: cgImage)
                    extractedFrames.append(uiImage)
                }
            }
        }
        
        group.notify(queue: .main) {
            if extractedFrames.isEmpty {
                completion(.failure(ImageValidationError.noFramesExtracted))
            } else {
                completion(.success(extractedFrames))
            }
        }
    }
    
    /// Validates multiple video frames
    private func validateVideoFrames(_ frames: [UIImage], completion: @escaping (Result<Bool, Error>) -> Void) {
        let group = DispatchGroup()
        var validationResults: [Bool] = []
        var validationErrors: [Error] = []
        
        for frame in frames {
            group.enter()
            validateSurfImage(frame) { result in
                switch result {
                case .success(let isValid):
                    validationResults.append(isValid)
                case .failure(let error):
                    validationErrors.append(error)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if !validationErrors.isEmpty {
                completion(.failure(validationErrors.first!))
                return
            }
            
            // Consider video valid if at least 30% of frames are valid
            let validFrames = validationResults.filter { $0 }.count
            let validationThreshold = max(1, Int(Double(validationResults.count) * 0.3))
            let isValid = validFrames >= validationThreshold
            
            completion(.success(isValid))
        }
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
