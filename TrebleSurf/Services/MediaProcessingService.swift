import Foundation
import UIKit
import SwiftUI
import CoreGraphics
import ImageIO
import Photos
import PhotosUI
import AVFoundation

/// Shared service for media processing operations used by both
/// SurfReportSubmissionViewModel and QuickPhotoReportViewModel.
///
/// Handles image compression, video thumbnail generation, and
/// timestamp extraction from media metadata.
@MainActor
class MediaProcessingService {

    private let logger: ErrorLoggerProtocol

    init(logger: ErrorLoggerProtocol) {
        self.logger = logger
    }

    // MARK: - Image Compression

    /// Compresses image to under 1MB while maintaining quality for surf reports.
    /// Returns the compressed image as a base64-encoded string.
    func compressImageForUpload(_ image: UIImage?) -> String? {
        guard let data = compressImageForUploadRaw(image) else { return nil }
        return data.base64EncodedString()
    }

    /// Compresses image to under 1MB and returns raw Data for S3 upload.
    func compressImageForUploadRaw(_ image: UIImage?) -> Data? {
        guard let image = image else { return nil }

        // Start with aggressive compression
        var compressionQuality: CGFloat = 0.5
        var imageData: Data?

        // Try to get image under 1MB with progressive compression
        repeat {
            imageData = image.jpegData(compressionQuality: compressionQuality)
            compressionQuality -= 0.1

            // Prevent infinite loop and ensure minimum quality
            if compressionQuality < 0.1 {
                break
            }
        } while imageData?.count ?? 0 > 1_000_000 // 1MB limit

        // If still too large, resize the image
        if let data = imageData, data.count > 1_000_000 {
            let resizedImage = resizeImage(image, targetSize: CGSize(width: 1200, height: 1200))
            imageData = resizedImage.jpegData(compressionQuality: 0.4)
        }

        return imageData
    }

    /// Resizes image to target dimensions while maintaining aspect ratio.
    func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
        let size = image.size

        let widthRatio  = targetSize.width  / size.width
        let heightRatio = targetSize.height / size.height

        // Use the smaller ratio to ensure image fits within target size
        let newSize: CGSize
        if widthRatio < heightRatio {
            newSize = CGSize(width: size.width * widthRatio, height: size.height * widthRatio)
        } else {
            newSize = CGSize(width: size.width * heightRatio, height: size.height * heightRatio)
        }

        let rect = CGRect(x: 0, y: 0, width: newSize.width, height: newSize.height)

        UIGraphicsBeginImageContextWithOptions(newSize, false, 1.0)
        image.draw(in: rect)
        let newImage = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()

        return newImage ?? image
    }

    // MARK: - Video Thumbnail Generation

    /// Generates a thumbnail image from a video URL.
    func generateVideoThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true

        do {
            let cgImage = try await imageGenerator.image(at: CMTime.zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            logger.log("Failed to generate thumbnail: \(error)", level: .error, category: .media)
            return nil
        }
    }

    // MARK: - Timestamp Extraction

    /// Parses an image date string from various EXIF/TIFF formats.
    func parseImageDate(_ dateString: String) -> Date? {
        let formatters = [
            "yyyy:MM:dd HH:mm:ss",
            "yyyy-MM-dd HH:mm:ss",
            "yyyy/MM/dd HH:mm:ss"
        ]

        for format in formatters {
            let formatter = DateFormatter()
            formatter.dateFormat = format
            formatter.locale = Locale(identifier: "en_US_POSIX")

            if let date = formatter.date(from: dateString) {
                return date
            }
        }

        return nil
    }

    /// Attempts to get file creation date as fallback when EXIF/TIFF data is not available.
    /// Tries PHAsset creation date first, then falls back to image source file properties.
    func getFileCreationDate(from imageSelection: PhotosPickerItem) async -> Date? {
        do {
            // Try to load the asset identifier to access PHAsset
            if let assetIdentifier = imageSelection.itemIdentifier {
                logger.log("Asset identifier: \(assetIdentifier)", level: .debug, category: .media)

                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                logger.log("Fetch result count: \(fetchResult.count)", level: .debug, category: .media)

                if let asset = fetchResult.firstObject {
                    logger.log("PHAsset found: creation date: \(asset.creationDate?.description ?? "nil"), modification date: \(asset.modificationDate?.description ?? "nil"), media type: \(asset.mediaType.rawValue), media subtypes: \(asset.mediaSubtypes.rawValue)", level: .debug, category: .media)

                    // Try creation date first
                    if let creationDate = asset.creationDate {
                        logger.log("Using PHAsset creation date: \(creationDate)", level: .debug, category: .media)
                        return creationDate
                    }

                    // Fallback to modification date if creation date is nil
                    if let modificationDate = asset.modificationDate {
                        logger.log("Using PHAsset modification date as fallback: \(modificationDate)", level: .debug, category: .media)
                        return modificationDate
                    }

                    logger.log("Both creation and modification dates are nil", level: .debug, category: .media)
                } else {
                    logger.log("No PHAsset found for identifier", level: .debug, category: .media)
                }
            } else {
                logger.log("No asset identifier available", level: .debug, category: .media)
            }

            // Alternative approach: try to get the image data and check file attributes
            logger.log("Trying alternative method with image data...", level: .debug, category: .media)
            if let data = try await imageSelection.loadTransferable(type: Data.self) {
                // Try to get file creation date from the data itself
                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
                    if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                        logger.log("Image source properties available", level: .debug, category: .media)

                        // Check for file creation date in properties
                        if let fileCreationDate = properties["{File}"] as? [String: Any],
                           let creationDate = fileCreationDate["FileCreationDate"] as? Date {
                            logger.log("Found file creation date in properties: \(creationDate)", level: .debug, category: .media)
                            return creationDate
                        }

                        // Check for file modification date
                        if let fileModificationDate = properties["{File}"] as? [String: Any],
                           let modificationDate = fileModificationDate["FileModificationDate"] as? Date {
                            logger.log("Found file modification date in properties: \(modificationDate)", level: .debug, category: .media)
                            return modificationDate
                        }

                        logger.log("No file dates found in image properties. Available properties: \(properties.keys)", level: .debug, category: .media)
                    }
                }
            }

        } catch {
            logger.log("Error accessing file creation date: \(error)", level: .error, category: .media)
        }

        logger.log("All methods failed to find file creation date", level: .debug, category: .media)
        return nil
    }
}
