import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics
import UIKit
import Photos
import ImageIO
import AVFoundation

// MARK: - Quick Photo Report View Model

@MainActor
class QuickPhotoReportViewModel: BaseViewModel {
    @Published var selectedImage: UIImage? = nil
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    @Published var selectedVideo: PhotosPickerItem? = nil {
        didSet {
            logger.log("Video selection changed: \(selectedVideo != nil ? "Selected" : "Nil")", level: .debug, category: .media)
            Task {
                await loadVideo()
            }
        }
    }
    @Published var selectedVideoURL: URL? = nil {
        didSet {
            // Keep track of video URL for cleanup in deinit (nonisolated)
            temporaryVideoURL = selectedVideoURL
        }
    }
    @Published var selectedVideoThumbnail: UIImage? = nil
    @Published var selectedDateTime: Date = Date()
    @Published var photoTimestampExtracted: Bool = false
    @Published var showTimestampSelector: Bool = false
    @Published var quality: Quality = .average
    @Published var waveSize: WaveSize = .kneeWaist
    @Published var isSubmitting = false
    @Published var shouldDismiss = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage: String?
    @Published var currentError: ErrorPresentation?
    override var fieldErrors: [String: String] {
        get { super.fieldErrors }
        set { super.fieldErrors = newValue }
    }

    private let apiClient: APIClientProtocol
    private let authManager: any AuthManagerProtocol
    private let imageValidationService: ImageValidationService
    private let mediaProcessingService: MediaProcessingService
    private let mediaUploadService: MediaUploadService

    // Track submission success to avoid cleanup after successful submission
    @Published var submissionSuccessful = false

    init(
        apiClient: APIClientProtocol,
        authManager: any AuthManagerProtocol,
        imageValidationService: ImageValidationService = ImageValidationService(),
        mediaProcessingService: MediaProcessingService,
        mediaUploadService: MediaUploadService,
        errorHandler: ErrorHandlerProtocol? = nil,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.authManager = authManager
        self.imageValidationService = imageValidationService
        self.mediaProcessingService = mediaProcessingService
        self.mediaUploadService = mediaUploadService
        super.init(errorHandler: errorHandler, logger: logger)
    }

    // Media validation properties
    @Published var isValidatingImage = false
    @Published var imageValidationError: String?
    @Published var imageValidationPassed = false
    @Published var isValidatingVideo = false
    @Published var videoValidationError: String?
    @Published var videoValidationPassed = false

    // S3 upload properties
    @Published var isUploadingImage = false
    @Published var uploadProgress: Double = 0.0
    @Published var imageKey: String?
    @Published var uploadUrl: String?
    @Published var isUploadingVideo = false
    @Published var videoUploadProgress: Double = 0.0
    @Published var videoKey: String?
    @Published var videoUploadUrl: String?
    @Published var isUploadingVideoThumbnail = false
    @Published var videoThumbnailKey: String?

    private var spotId: String?

    // Safety: Only written from @MainActor setter, read from nonisolated deinit for cleanup.
    nonisolated(unsafe) private var temporaryVideoURL: URL?

    deinit {
        // Clean up temporary video file when view model is deallocated
        if let videoURL = temporaryVideoURL {
            cleanupTemporaryVideoFile(videoURL)
        }
    }

    var canSubmit: Bool {
        let hasImage = selectedImage != nil && imageValidationPassed && !isValidatingImage
        let hasVideo = selectedVideoURL != nil && videoValidationPassed && !isValidatingVideo
        return hasImage || hasVideo
    }

    @MainActor
    private func loadImage() async {
        guard let imageSelection = imageSelection else {
            return
        }

        do {
            if let data = try await imageSelection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImage = image

                // Validate image using iOS ML
                await validateImage(image)

                // Try to extract timestamp from image metadata
                var timestampFound = false
                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
                   let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {

                    // Check for EXIF date
                    if let exif = properties["{Exif}"] as? [String: Any],
                       let dateTimeOriginal = exif["DateTimeOriginal"] as? String {
                        if let extractedDate = mediaProcessingService.parseImageDate(dateTimeOriginal) {
                            selectedDateTime = extractedDate
                            timestampFound = true
                            logger.log("Found EXIF timestamp: \(extractedDate)", level: .debug, category: .media)
                        }
                    }
                    // Check for TIFF date
                    else if let tiff = properties["{TIFF}"] as? [String: Any],
                            let dateTime = tiff["DateTime"] as? String {
                        if let extractedDate = mediaProcessingService.parseImageDate(dateTime) {
                            selectedDateTime = extractedDate
                            timestampFound = true
                            logger.log("Found TIFF timestamp: \(extractedDate)", level: .debug, category: .media)
                        }
                    }
                }

                // If no timestamp found in metadata, try to use file creation date as fallback
                if !timestampFound {
                    if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: imageSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        logger.log("Using file creation date as fallback: \(fileCreationDate)", level: .debug, category: .media)
                    }
                }

                // Update the flag
                photoTimestampExtracted = timestampFound

                // Log final timestamp status and show timestamp selector if needed
                if !timestampFound {
                    logger.log("No timestamp found - will show timestamp selector", level: .warning, category: .media)
                    showTimestampSelector = true
                } else {
                    showTimestampSelector = false
                }

                // If we already have a presigned URL, start upload immediately
                if let uploadUrl = self.uploadUrl, let _ = self.imageKey {
                    Task {
                        do {
                            try await mediaUploadService.uploadImageToS3(uploadURL: uploadUrl, image: image)
                        } catch {
                            // Could show error to user here if needed
                        }
                    }
                } else if self.spotId != nil {
                    // No presigned URL yet, but spotId available - upload will start when URL is ready
                } else {
                    // Neither presigned URL nor spotId available
                }
            }
        } catch {
            // Failed to load image:
        }
    }

    @MainActor
    private func validateImage(_ image: UIImage) async {
        isValidatingImage = true
        imageValidationError = nil
        imageValidationPassed = false

        do {
            let isValid = try await imageValidationService.validateSurfImage(image)
            isValidatingImage = false
            imageValidationPassed = isValid
            if !isValid {
                imageValidationError = "This image doesn't appear to contain surf-related content. Please select a photo that shows waves, surfers, or the ocean."
            }
        } catch {
            isValidatingImage = false
            imageValidationPassed = false
            imageValidationError = "Failed to validate image: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func loadVideo() async {
        logger.log("Starting video load process", level: .info, category: .media)
        guard let videoSelection = selectedVideo else {
            logger.log("No video selection found", level: .warning, category: .media)
            return
        }

        logger.log("Video selection found, loading transferable...", level: .debug, category: .media)
        do {
            // Try loading as Data first, then convert to URL
            logger.log("Attempting to load video as Data...", level: .debug, category: .media)
            if let videoData = try await videoSelection.loadTransferable(type: Data.self) {
                logger.log("Video data loaded successfully, size: \(videoData.count) bytes", level: .info, category: .media)

                // Create a temporary file URL
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileName = "temp_video_\(UUID().uuidString).mov"
                let tempURL = tempDirectory.appendingPathComponent(tempFileName)

                do {
                    try videoData.write(to: tempURL)
                    logger.log("Video data written to temporary file: \(tempURL)", level: .debug, category: .media)
                    selectedVideoURL = tempURL

                    // Generate thumbnail
                    logger.log("Generating video thumbnail...", level: .debug, category: .media)
                    if let thumbnail = await mediaProcessingService.generateVideoThumbnail(from: tempURL) {
                        logger.log("Video thumbnail generated successfully", level: .info, category: .media)
                        selectedVideoThumbnail = thumbnail
                    } else {
                        logger.log("Failed to generate video thumbnail", level: .warning, category: .media)
                    }

                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        logger.log("Using video creation date: \(fileCreationDate)", level: .debug, category: .media)
                    }

                    // Update timestamp selector visibility
                    if !timestampFound {
                        logger.log("No video timestamp found - will show timestamp selector", level: .warning, category: .media)
                        showTimestampSelector = true
                    } else {
                        showTimestampSelector = false
                    }

                    // Validate video using iOS ML
                    logger.log("Starting video validation...", level: .debug, category: .media)
                    await validateVideo(tempURL)

                    // Start video upload process
                    if let spotId = self.spotId {
                        logger.log("Starting video upload process for spotId", level: .info, category: .media)
                        await startVideoUploadProcess(spotId: spotId, videoURL: tempURL)
                    } else {
                        logger.log("No spotId available for video upload", level: .warning, category: .media)
                    }
                } catch {
                    logger.log("Failed to write video data to temporary file: \(error.localizedDescription)", level: .error, category: .media)
                }
            } else {
                logger.log("Failed to load video data from selection, trying URL approach...", level: .warning, category: .media)
                // Fallback: try loading as URL directly
                if let videoURL = try await videoSelection.loadTransferable(type: URL.self) {
                    logger.log("Video URL loaded successfully via fallback", level: .info, category: .media)
                    selectedVideoURL = videoURL

                    // Generate thumbnail
                    logger.log("Generating video thumbnail...", level: .debug, category: .media)
                    if let thumbnail = await mediaProcessingService.generateVideoThumbnail(from: videoURL) {
                        logger.log("Video thumbnail generated successfully", level: .info, category: .media)
                        selectedVideoThumbnail = thumbnail
                    } else {
                        logger.log("Failed to generate video thumbnail", level: .warning, category: .media)
                    }

                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        logger.log("Using video creation date: \(fileCreationDate)", level: .debug, category: .media)
                    }

                    // Update timestamp selector visibility
                    if !timestampFound {
                        logger.log("No video timestamp found - will show timestamp selector", level: .warning, category: .media)
                        showTimestampSelector = true
                    } else {
                        showTimestampSelector = false
                    }

                    // Validate video using iOS ML
                    logger.log("Starting video validation...", level: .debug, category: .media)
                    await validateVideo(videoURL)

                    // Start video upload process
                    if let spotId = self.spotId {
                        logger.log("Starting video upload process for spotId", level: .info, category: .media)
                        await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
                    } else {
                        logger.log("No spotId available for video upload", level: .warning, category: .media)
                    }
                } else {
                    logger.log("Failed to load video URL from selection via fallback", level: .error, category: .media)
                }
            }
        } catch {
            logger.log("Failed to load video: \(error.localizedDescription)", level: .error, category: .media)
        }
    }

    @MainActor
    private func validateVideo(_ videoURL: URL) async {
        logger.log("Starting video validation for URL", level: .debug, category: .media)
        isValidatingVideo = true
        videoValidationError = nil
        videoValidationPassed = false

        do {
            let isValid = try await imageValidationService.validateSurfVideo(videoURL)
            isValidatingVideo = false
            logger.log("Video validation completed. Valid: \(isValid)", level: .info, category: .media)
            videoValidationPassed = isValid
            if !isValid {
                logger.log("Video validation failed - not surf-related content", level: .warning, category: .media)
                videoValidationError = "This video doesn't appear to contain surf-related content. Please select a video that shows waves, surfers, or the ocean."
            } else {
                logger.log("Video validation passed", level: .info, category: .media)
            }
        } catch {
            isValidatingVideo = false
            logger.log("Video validation error: \(error.localizedDescription)", level: .error, category: .media)
            videoValidationPassed = false
            videoValidationError = "Failed to validate video: \(error.localizedDescription)"
        }
    }

    private func startVideoUploadProcess(spotId: String, videoURL: URL) async {
        logger.log("Starting video upload process for spotId", level: .info, category: .media)
        do {
            // First, upload the video thumbnail as an image
            if let thumbnail = selectedVideoThumbnail {
                logger.log("Uploading video thumbnail as image...", level: .debug, category: .media)
                isUploadingVideoThumbnail = true
                if let thumbnailKey = await mediaUploadService.uploadVideoThumbnail(spotId: spotId, thumbnail: thumbnail) {
                    videoThumbnailKey = thumbnailKey
                }
                isUploadingVideoThumbnail = false
            }

            // Then upload the video
            logger.log("Generating presigned upload URL for video...", level: .debug, category: .media)
            let videoUploadResponse = try await mediaUploadService.generateVideoUploadURL(spotId: spotId)
            videoUploadUrl = videoUploadResponse.uploadUrl
            videoKey = videoUploadResponse.videoKey
            logger.log("Presigned URL generated. Key: \(videoUploadResponse.videoKey)", level: .info, category: .media)

            // Start video upload
            logger.log("Starting S3 video upload...", level: .info, category: .media)
            isUploadingVideo = true
            videoUploadProgress = 0.0
            try await mediaUploadService.uploadVideoToS3(uploadURL: videoUploadResponse.uploadUrl, videoURL: videoURL)
            videoUploadProgress = 1.0
            isUploadingVideo = false
            logger.log("Video upload completed successfully", level: .info, category: .media)
        } catch {
            isUploadingVideo = false
            logger.log("Failed to start video upload process: \(error.localizedDescription)", level: .error, category: .media)
        }
    }

    /// Pre-generates presigned URL when user clicks "Add Photo" for better performance
    func preGenerateUploadURL() async {
        guard let spotId = self.spotId else {
            return
        }

        do {
            let uploadResponse = try await mediaUploadService.generateImageUploadURL(spotId: spotId)

            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
            }

        } catch {
            // Don't show error to user since this is just optimization
        }
    }

    func clearImage() {
        selectedImage = nil
        imageSelection = nil
        photoTimestampExtracted = false
        showTimestampSelector = false
        // Reset to current time when photo is cleared
        selectedDateTime = Date()

        // Clear S3 upload state
        imageKey = nil
        uploadUrl = nil
        isUploadingImage = false
        uploadProgress = 0.0

        // Clear validation state
        imageValidationPassed = false
        imageValidationError = nil
        isValidatingImage = false
    }

    func clearVideo() {
        // Clean up temporary video file
        if let videoURL = selectedVideoURL {
            cleanupTemporaryVideoFile(videoURL)
        }

        selectedVideo = nil
        selectedVideoURL = nil
        selectedVideoThumbnail = nil
        photoTimestampExtracted = false
        showTimestampSelector = false
        // Reset to current time when video is cleared
        selectedDateTime = Date()

        // Clear S3 upload state
        videoKey = nil
        videoUploadUrl = nil
        isUploadingVideo = false
        videoUploadProgress = 0.0
        videoThumbnailKey = nil
        isUploadingVideoThumbnail = false

        // Clear validation state
        videoValidationPassed = false
        videoValidationError = nil
        isValidatingVideo = false
    }

    nonisolated private func cleanupTemporaryVideoFile(_ videoURL: URL) {
        do {
            try FileManager.default.removeItem(at: videoURL)
            // Cannot access logger from nonisolated context (MainActor-isolated)
        } catch {
            // Cannot access logger from nonisolated context (MainActor-isolated)
        }
    }

    func clearMedia() {
        clearImage()
        clearVideo()
    }

    /// Starts the S3 upload process: generate URL, then upload image
    private func startImageUploadProcess() async {
        guard let image = selectedImage else {
            return
        }
        guard let spotId = self.spotId else {
            return
        }
        await generateUploadURLAndUploadImage(spotId: spotId, image: image)
    }

    /// Sets the spotId and starts image/video upload if media is already selected
    func setSpotId(_ spotId: String) {
        logger.log("Setting spotId: \(spotId)", level: .debug, category: .general)
        self.spotId = spotId

        // If we already have an image selected but haven't started upload, start it now
        if selectedImage != nil && imageKey == nil && !isUploadingImage {
            logger.log("Starting image upload for existing selection", level: .info, category: .network)
            Task {
                await startImageUploadProcess(spotId: spotId)
            }
        }

        // If we already have a video selected but haven't started upload, start it now
        if selectedVideoURL != nil && videoKey == nil && !isUploadingVideo {
            logger.log("Starting video upload for existing selection", level: .info, category: .network)
            Task {
                await startVideoUploadProcess(spotId: spotId, videoURL: selectedVideoURL!)
            }
        }
    }

    /// Starts the S3 upload process with a specific spotId
    func startImageUploadProcess(spotId: String) async {
        guard let image = selectedImage else { return }
        await generateUploadURLAndUploadImage(spotId: spotId, image: image)
    }

    /// Generates presigned URL and uploads image to S3
    private func generateUploadURLAndUploadImage(spotId: String, image: UIImage) async {
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }

        do {
            // Step 1: Generate presigned upload URL
            let uploadResponse = try await mediaUploadService.generateImageUploadURL(spotId: spotId)

            await MainActor.run {
                self.uploadProgress = 0.5
            }

            // Step 2: Upload image to S3
            try await mediaUploadService.uploadImageToS3(uploadURL: uploadResponse.uploadUrl, image: image)

            await MainActor.run {
                self.isUploadingImage = false
                self.uploadProgress = 1.0
            }

        } catch {
            await MainActor.run {
                self.isUploadingImage = false
                // Use the error handling system
                self.handleSubmissionError(error)
            }
        }
    }

    @MainActor
    func submitQuickReport(spotId: String) async {
        guard canSubmit else { return }

        isSubmitting = true
        errorMessage = nil
        fieldErrors = [:] // Clear previous field errors

        // Set the spotId for image uploads if not already set
        if self.spotId == nil {
            setSpotId(spotId)
        }

        // Convert spotId back to country/region/spot format
        logger.log("Parsing spotId: \(spotId)", level: .debug, category: .dataProcessing)
        let components = spotId.split(separator: "#")
        logger.log("SpotId components: \(components)", level: .debug, category: .dataProcessing)
        guard components.count >= 3 else {
            logger.log("Invalid spot format - not enough components", level: .error, category: .validation)
            errorMessage = "Invalid spot format"
            showErrorAlert = true
            isSubmitting = false
            return
        }

        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        logger.log("Parsed - Country: \(country), Region: \(region), Spot: \(spot)", level: .debug, category: .dataProcessing)

        // Convert local time to UTC before sending to backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC") // Format as UTC
        let formattedDate = dateFormatter.string(from: selectedDateTime)

        // Debug timezone information
        logger.log("Selected date (local): \(selectedDateTime), Current timezone: \(TimeZone.current.identifier), Formatted date (UTC): \(formattedDate)", level: .debug, category: .dataProcessing)

        // Determine which image key to use (regular image or video thumbnail)
        let finalImageKey: String
        if let videoThumbnailKey = videoThumbnailKey {
            // If we have a video thumbnail, use that as the image
            finalImageKey = videoThumbnailKey
        } else {
            // Otherwise use the regular image key
            finalImageKey = imageKey ?? ""
        }

        // Prepare report data with default values for quick report
        let reportData: [String: Any] = [
            "country": country,
            "region": region,
            "spot": spot,
            "surfSize": waveSize.rawValue,
            "messiness": "clean", // Default value
            "windDirection": "no-wind", // Default value
            "windAmount": "light", // Default value
            "consistency": "consistent", // Default value
            "quality": quality.rawValue,
            "imageKey": finalImageKey,
            "videoKey": videoKey ?? "",
            "date": formattedDate
        ]

        do {
            let success = try await submitSurfReport(reportData)

            if success {
                submissionSuccessful = true
                showSuccessAlert = true
                // Dismiss after a short delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    self.shouldDismiss = true
                }
            } else {
                // Handle submission failure
                handleSubmissionError(NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to submit report"]))
            }
        } catch {
            // Use the error handling system
            handleSubmissionError(error)
        }

        isSubmitting = false
    }

    private func submitSurfReport(_ reportData: [String: Any]) async throws -> Bool {
        // Use iOS validation endpoint for all submissions
        let endpoint = Endpoints.createSurfReportWithIOSValidation

        // Add iOS validation flag and media type
        var finalReportData = reportData
        finalReportData["iosValidated"] = true

        // Set media type
        if imageKey != nil && videoKey != nil {
            finalReportData["mediaType"] = "both"
        } else if imageKey != nil {
            finalReportData["mediaType"] = "image"
        } else if videoKey != nil {
            finalReportData["mediaType"] = "video"
        }

        // Log the final request data for debugging
        logger.log("Final report data being sent: \(finalReportData)", level: .debug, category: .api)

        // Check if we have any media keys
        logger.log("Media keys - Image: \(imageKey ?? "nil"), Video: \(videoKey ?? "nil")", level: .debug, category: .api)

        // Convert to Data for APIClient
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: finalReportData)
        } catch {
            throw error
        }

        // Check if we have a CSRF token, refresh if needed
        if authManager.getCsrfHeader() == nil {
            _ = await apiClient.refreshCSRFToken()
        }

        // Use APIClient which handles CSRF tokens and session cookies automatically
        do {
            _ = try await apiClient.postRequest(to: endpoint, body: jsonData) as SurfReportSubmissionResponse
            return true
        } catch {
            // If it's a 403 error, try refreshing the CSRF token and retry once
            if let nsError = error as NSError?, nsError.code == 403 {
                let refreshed = await apiClient.refreshCSRFToken()
                if refreshed {
                    do {
                        _ = try await apiClient.postRequest(to: endpoint, body: jsonData) as SurfReportSubmissionResponse
                        return true
                    } catch {
                        return false
                    }
                }
            }
            return false
        }
    }

    // MARK: - Error Handling

    @MainActor
    func handleSubmissionError(_ error: Error) {
        // Use BaseViewModel's error handling
        handleError(error, context: "Quick photo report submission")

        // Create error presentation from the modern error system
        let trebleError = TrebleSurfError.from(error)
        let presentation = ErrorPresentation(from: trebleError)
        self.currentError = presentation
        self.errorMessage = presentation.message

        // Set field-specific errors if applicable
        if let fieldName = presentation.fieldName {
            self.fieldErrors[fieldName] = presentation.helpText
        }

        // Show error alert
        self.showErrorAlert = true
    }

    // Note: clearFieldError is available from BaseViewModel extension, no need to override
    // Keeping this method for any custom logic if needed in the future

    func clearAllErrors() {
        currentError = nil
        errorMessage = nil
        fieldErrors.removeAll()
        showErrorAlert = false
    }

    func getFieldError(for fieldName: String) -> String? {
        return fieldErrors[fieldName]
    }

    func hasFieldError(for fieldName: String) -> Bool {
        return fieldErrors[fieldName] != nil
    }

    // MARK: - Retry Methods

    func retrySubmission(spotId: String) {
        // Clear any previous errors
        clearAllErrors()

        // Retry the submission
        Task {
            await submitQuickReport(spotId: spotId)
        }
    }

    func retryImageUpload(spotId: String) {
        // Clear errors but preserve image state for retry
        currentError = nil
        errorMessage = nil
        fieldErrors.removeAll()
        showErrorAlert = false

        // Clear the current image and reset image state
        selectedImage = nil
        imageKey = nil
        isUploadingImage = false
        uploadProgress = 0.0

        // Generate a new presigned URL for the retry
        Task {
            await preGenerateUploadURL()
        }
    }

    // MARK: - Cleanup Functions

    /// Cleans up unused uploaded media when user dismisses the form
    func cleanupUnusedUploads() {
        // Don't cleanup if submission was successful - the media is now part of a report
        if submissionSuccessful {
            logger.log("Skipping cleanup - submission was successful", level: .info, category: .general)
            return
        }

        logger.log("Cleaning up unused uploads after cancellation", level: .info, category: .general)
        Task {
            await mediaUploadService.cleanupUnusedMedia(
                imageKey: imageKey,
                videoKey: videoKey,
                videoThumbnailKey: videoThumbnailKey
            )
        }
    }
}
