import Foundation
import UIKit

/// Shared service for S3 media upload operations used by both
/// SurfReportSubmissionViewModel and QuickPhotoReportViewModel.
///
/// Handles presigned URL generation, S3 uploads for images and videos,
/// thumbnail uploads, and media cleanup/deletion.
@MainActor
class MediaUploadService {

    private let apiClient: APIClientProtocol
    private let mediaProcessingService: MediaProcessingService
    private let logger: ErrorLoggerProtocol

    init(
        apiClient: APIClientProtocol,
        mediaProcessingService: MediaProcessingService,
        logger: ErrorLoggerProtocol
    ) {
        self.apiClient = apiClient
        self.mediaProcessingService = mediaProcessingService
        self.logger = logger
    }

    // MARK: - Spot ID Parsing

    /// Parses a composite spotId (country#region#spot) into its component parts.
    /// Throws if the format is invalid.
    private func parseSpotId(_ spotId: String) throws -> (country: String, region: String, spot: String) {
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            logger.log("Invalid spot format: \(spotId)", level: .error, category: .validation)
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid spot format"])
        }
        return (String(components[0]), String(components[1]), String(components[2]))
    }

    // MARK: - Presigned URL Generation

    /// Generates a presigned upload URL for an image from the backend.
    func generateImageUploadURL(spotId: String) async throws -> PresignedUploadResponse {
        logger.log("Generating presigned upload URL for spotId: \(spotId)", level: .info, category: .network)

        let parsed = try parseSpotId(spotId)
        let endpoint = "/api/generateImageUploadURL?country=\(parsed.country)&region=\(parsed.region)&spot=\(parsed.spot)"
        logger.log("Requesting presigned URL from: \(endpoint)", level: .debug, category: .network)

        do {
            let response: PresignedUploadResponse = try await apiClient.request(endpoint)
            logger.log("Presigned URL response received", level: .debug, category: .network)
            logger.log("Image key: \(response.imageKey)", level: .debug, category: .network)
            logger.log("Upload URL: \(response.uploadUrl.prefix(50))...", level: .debug, category: .network)
            logger.log("Expires at: \(response.expiresAt)", level: .debug, category: .network)
            return response
        } catch {
            logger.log("Failed to generate presigned URL: \(error)", level: .error, category: .network)
            if let nsError = error as NSError? {
                logger.log("Error details - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription), User Info: \(nsError.userInfo)", level: .error, category: .network)
            }
            throw error
        }
    }

    /// Generates a presigned upload URL for a video from the backend.
    func generateVideoUploadURL(spotId: String) async throws -> PresignedVideoUploadResponse {
        logger.log("Generating presigned video upload URL for spotId: \(spotId)", level: .info, category: .network)

        let parsed = try parseSpotId(spotId)
        let endpoint = "/api/generateVideoUploadURL?country=\(parsed.country)&region=\(parsed.region)&spot=\(parsed.spot)"
        logger.log("Requesting presigned video URL from: \(endpoint)", level: .debug, category: .network)

        do {
            let response: PresignedVideoUploadResponse = try await apiClient.request(endpoint)
            logger.log("Presigned video URL response received", level: .debug, category: .network)
            logger.log("Video key: \(response.videoKey)", level: .debug, category: .network)
            logger.log("Upload URL: \(response.uploadUrl.prefix(50))...", level: .debug, category: .network)
            return response
        } catch {
            logger.log("Failed to generate presigned video URL: \(error)", level: .error, category: .network)
            if let nsError = error as NSError? {
                logger.log("Error details - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription), User Info: \(nsError.userInfo)", level: .error, category: .network)
            }
            throw error
        }
    }

    // MARK: - S3 Upload

    /// Uploads an image (UIImage) to S3 using a presigned URL.
    /// Compresses the image before uploading.
    func uploadImageToS3(uploadURL: String, image: UIImage) async throws {
        logger.log("Starting S3 upload process", level: .info, category: .network)
        logger.log("Function called with URL: \(uploadURL.prefix(50))...", level: .debug, category: .network)
        logger.log("Image size: \(image.size)", level: .debug, category: .media)

        guard let url = URL(string: uploadURL) else {
            logger.log("Invalid upload URL: \(uploadURL)", level: .error, category: .network)
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }

        // Compress image for upload - get raw JPEG data, not base64 string
        logger.log("Compressing image for upload...", level: .debug, category: .media)
        guard let imageData = mediaProcessingService.compressImageForUploadRaw(image) else {
            logger.log("Failed to compress image", level: .error, category: .media)
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }

        logger.log("Image compressed to \(imageData.count) bytes", level: .debug, category: .media)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        request.timeoutInterval = 30 // 30 second timeout
        request.allowsCellularAccess = true // Allow cellular fallback

        logger.log("Sending PUT request to S3...", level: .info, category: .network)
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            logger.log("Request header - \(key): \(value)", level: .debug, category: .network)
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.log("Invalid response from S3 - not HTTPURLResponse", level: .error, category: .network)
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }

        logger.log("S3 response status code: \(httpResponse.statusCode)", level: .debug, category: .network)
        for (key, value) in httpResponse.allHeaderFields {
            logger.log("Response header - \(key): \(value)", level: .debug, category: .network)
        }

        if !data.isEmpty {
            if let responseString = String(data: data, encoding: .utf8) {
                logger.log("Response body: \(responseString)", level: .debug, category: .network)
            }
        }

        guard httpResponse.statusCode == 200 else {
            logger.log("S3 upload failed with status: \(httpResponse.statusCode)", level: .error, category: .network)
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to S3 - Status: \(httpResponse.statusCode)"])
        }

        logger.log("Image successfully uploaded to S3", level: .debug, category: .network)
    }

    /// Uploads raw image data to S3 using a presigned URL.
    /// Used for uploading pre-compressed image data (e.g., video thumbnails).
    func uploadImageDataToS3(uploadURL: String, imageData: Data) async throws {
        logger.log("Uploading image data to S3...", level: .info, category: .network)

        guard let url = URL(string: uploadURL) else {
            logger.log("Invalid upload URL: \(uploadURL)", level: .error, category: .network)
            throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        request.timeoutInterval = 30 // 30 second timeout
        request.allowsCellularAccess = true // Allow cellular fallback

        let (_, response) = try await URLSession.shared.data(for: request)

        if let httpResponse = response as? HTTPURLResponse {
            logger.log("S3 image upload response status: \(httpResponse.statusCode)", level: .debug, category: .network)
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image upload failed with status: \(httpResponse.statusCode)"])
            }
        }
    }

    /// Uploads a video to S3 using a presigned URL.
    func uploadVideoToS3(uploadURL: String, videoURL: URL) async throws {
        logger.log("Starting S3 video upload process", level: .info, category: .network)
        logger.log("Upload URL: \(uploadURL.prefix(50))...", level: .debug, category: .network)

        guard let url = URL(string: uploadURL) else {
            logger.log("Invalid upload URL: \(uploadURL)", level: .error, category: .network)
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }

        // Read video data
        logger.log("Reading video data...", level: .debug, category: .media)
        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            logger.log("Failed to read video data: \(error)", level: .error, category: .media)
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to read video data"])
        }

        logger.log("Video data size: \(videoData.count) bytes", level: .debug, category: .media)

        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = videoData
        request.timeoutInterval = 60 // 60 second timeout for larger video files
        request.allowsCellularAccess = true // Allow cellular fallback

        logger.log("Sending PUT request to S3...", level: .info, category: .network)
        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            logger.log("Invalid response from S3 - not HTTPURLResponse", level: .error, category: .network)
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }

        logger.log("S3 response status code: \(httpResponse.statusCode)", level: .debug, category: .network)

        guard httpResponse.statusCode == 200 else {
            logger.log("S3 upload failed with status: \(httpResponse.statusCode)", level: .error, category: .network)
            if let responseHeaders = httpResponse.allHeaderFields as? [String: String] {
                logger.log("Response headers: \(responseHeaders)", level: .error, category: .network)
            }
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload video to S3 - Status: \(httpResponse.statusCode)"])
        }

        logger.log("Video successfully uploaded to S3", level: .debug, category: .network)
    }

    // MARK: - Thumbnail Upload

    /// Uploads a video thumbnail as an image to S3.
    /// Generates a presigned image upload URL, compresses the thumbnail, and uploads it.
    /// Returns the image key for the uploaded thumbnail, or nil on failure.
    func uploadVideoThumbnail(spotId: String, thumbnail: UIImage) async -> String? {
        logger.log("Starting video thumbnail upload...", level: .info, category: .network)

        do {
            // Generate presigned URL for image upload
            let imageUploadResponse = try await generateImageUploadURL(spotId: spotId)
            let thumbnailKey = imageUploadResponse.imageKey
            logger.log("Video thumbnail upload URL generated: \(thumbnailKey)", level: .debug, category: .network)

            // Compress and upload the thumbnail
            if let thumbnailData = mediaProcessingService.compressImageForUploadRaw(thumbnail) {
                try await uploadImageDataToS3(uploadURL: imageUploadResponse.uploadUrl, imageData: thumbnailData)
                logger.log("Video thumbnail uploaded successfully", level: .debug, category: .network)
                return thumbnailKey
            } else {
                logger.log("Failed to compress video thumbnail", level: .error, category: .media)
                return nil
            }
        } catch {
            logger.log("Failed to upload video thumbnail: \(error)", level: .error, category: .network)
            return nil
        }
    }

    // MARK: - Media Cleanup / Deletion

    /// Deletes a specific uploaded media file from S3 via the backend.
    func deleteUploadedMedia(key: String, type: String) async {
        logger.log("Deleting unused \(type): \(key)", level: .info, category: .general)

        do {
            let endpoint = "/api/deleteUploadedMedia?key=\(key)&type=\(type)"
            _ = try await apiClient.makeFlexibleRequest(to: endpoint, method: "DELETE", requiresAuth: true) as EmptyResponse
            logger.log("Successfully deleted \(type): \(key)", level: .debug, category: .general)
        } catch {
            logger.log("Error deleting \(type) \(key): \(error)", level: .error, category: .general)
        }
    }

    /// Cleans up multiple uploaded media keys concurrently.
    /// Pass nil for any key that should be skipped.
    func cleanupUnusedMedia(imageKey: String?, videoKey: String?, videoThumbnailKey: String?) async {
        var cleanupTasks: [Task<Void, Never>] = []

        if let imageKey = imageKey {
            logger.log("Scheduling cleanup for uploaded image: \(imageKey)", level: .info, category: .general)
            cleanupTasks.append(Task {
                await self.deleteUploadedMedia(key: imageKey, type: "image")
            })
        }

        if let videoKey = videoKey {
            logger.log("Scheduling cleanup for uploaded video: \(videoKey)", level: .info, category: .general)
            cleanupTasks.append(Task {
                await self.deleteUploadedMedia(key: videoKey, type: "video")
            })
        }

        if let videoThumbnailKey = videoThumbnailKey {
            logger.log("Scheduling cleanup for uploaded video thumbnail: \(videoThumbnailKey)", level: .info, category: .general)
            cleanupTasks.append(Task {
                await self.deleteUploadedMedia(key: videoThumbnailKey, type: "image")
            })
        }

        // Wait for all cleanup tasks to complete
        await withTaskGroup(of: Void.self) { group in
            for task in cleanupTasks {
                group.addTask { await task.value }
            }
        }

        logger.log("Unused media cleanup completed", level: .info, category: .general)
    }
}
