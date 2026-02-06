import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics
import UIKit
import Photos
import ImageIO
import AVFoundation



struct SurfReportOption: Identifiable {
    let id: String
    let title: String
    let iconName: String
}

struct SurfReportStep {
    let title: String
    let description: String
    let options: [SurfReportOption]
}

@MainActor
class SurfReportSubmissionViewModel: BaseViewModel {
    let instanceId = UUID()

    @Published var currentStep = 0
    @Published var selectedOptions: [Int: String] = [:]
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    @Published var videoSelection: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadVideo()
            }
        }
    }
    @Published var selectedImage: UIImage? = nil
    @Published var selectedVideoURL: URL? = nil {
        didSet {
            // Keep track of video URL for cleanup in deinit (nonisolated)
            temporaryVideoURL = selectedVideoURL
        }
    }
    @Published var selectedVideoThumbnail: UIImage? = nil
    @Published var selectedDateTime: Date = Date()
    @Published var photoTimestampExtracted: Bool = false
    @Published var isSubmitting = false
    @Published var shouldDismiss = false
    @Published var showSuccessAlert = false
    @Published var showErrorAlert = false
    @Published var errorMessage: String?
    @Published var currentError: ErrorPresentation?
    // fieldErrors inherited from BaseViewModel
    @Published var shouldShowPhotoPicker = false

    // Track submission success to avoid cleanup after successful submission
    @Published var submissionSuccessful = false

    // New properties for S3 upload workflow
    @Published var isUploadingImage = false
    @Published var isUploadingVideo = false
    @Published var uploadProgress: Double = 0.0
    @Published var videoUploadProgress: Double = 0.0
    @Published var imageKey: String?
    @Published var videoKey: String?
    @Published var uploadUrl: String?
    @Published var videoUploadUrl: String?
    @Published var videoThumbnailKey: String?
    @Published var isUploadingVideoThumbnail = false

    // Video validation properties
    @Published var isValidatingVideo = false
    @Published var videoValidationError: String?
    @Published var videoValidationPassed = false

    // Track upload failures
    @Published var imageUploadFailed = false
    @Published var videoUploadFailed = false

    // Store the spotId for image uploads
    private var spotId: String?

    private let apiClient: APIClientProtocol
    private let imageValidationService: ImageValidationService
    private let mediaProcessingService: MediaProcessingService
    private let mediaUploadService: MediaUploadService

    init(
        apiClient: APIClientProtocol,
        imageValidationService: ImageValidationService = ImageValidationService(),
        mediaProcessingService: MediaProcessingService,
        mediaUploadService: MediaUploadService,
        errorHandler: ErrorHandlerProtocol? = nil,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.imageValidationService = imageValidationService
        self.mediaProcessingService = mediaProcessingService
        self.mediaUploadService = mediaUploadService
        super.init(errorHandler: errorHandler, logger: logger)
    }

    // Safety: Only written from @MainActor setter, read from nonisolated deinit for cleanup.
    nonisolated(unsafe) private var temporaryVideoURL: URL?

    deinit {
        // Clean up temporary video file when view model is deallocated
        if let videoURL = temporaryVideoURL {
            cleanupTemporaryVideoFile(videoURL)
        }
    }

    // Track uploaded media for cleanup
    @Published var uploadedImageKey: String?
    @Published var uploadedVideoKey: String?
    @Published var uploadedVideoThumbnailKey: String?

    let steps: [SurfReportStep] = [
        SurfReportStep(
            title: "Wave Size",
            description: "What size are the waves?",
            options: [
                SurfReportOption(id: "flat", title: "Flat", iconName: "water.waves"),
                SurfReportOption(id: "knee-waist", title: "Knee to Waist", iconName: "water.waves"),
                SurfReportOption(id: "chest-shoulder", title: "Chest to Shoulder", iconName: "water.waves"),
                SurfReportOption(id: "head-high", title: "Head High", iconName: "water.waves"),
                SurfReportOption(id: "overhead", title: "Overhead", iconName: "water.waves"),
                SurfReportOption(id: "double-overhead", title: "Double Overhead", iconName: "water.waves")
            ]
        ),
        SurfReportStep(
            title: "Wave Messiness",
            description: "Are the waves clean or is there chop?",
            options: [
                SurfReportOption(id: "clean", title: "Clean", iconName: "leaf"),
                SurfReportOption(id: "slight-chop", title: "Slight Chop", iconName: "leaf"),
                SurfReportOption(id: "choppy", title: "Choppy", iconName: "leaf"),
                SurfReportOption(id: "messy", title: "Messy", iconName: "leaf")
            ]
        ),
        SurfReportStep(
            title: "Wind Direction",
            description: "What direction is the wind blowing?",
            options: [
                SurfReportOption(id: "onshore", title: "Onshore", iconName: "arrow.down"),
                SurfReportOption(id: "offshore", title: "Offshore", iconName: "arrow.up"),
                SurfReportOption(id: "cross-shore", title: "Cross Shore", iconName: "arrow.left.and.right"),
                SurfReportOption(id: "no-wind", title: "No Wind", iconName: "wind")
            ]
        ),
        SurfReportStep(
            title: "Wind Strength",
            description: "Is the wind strong?",
            options: [
                SurfReportOption(id: "light", title: "Light", iconName: "wind"),
                SurfReportOption(id: "moderate", title: "Moderate", iconName: "wind"),
                SurfReportOption(id: "strong", title: "Strong", iconName: "wind"),
                SurfReportOption(id: "very-strong", title: "Very Strong", iconName: "wind")
            ]
        ),
        SurfReportStep(
            title: "Wave Consistency",
            description: "How consistent are sets of waves?",
            options: [
                SurfReportOption(id: "setty", title: "Setty", iconName: "repeat"),
                SurfReportOption(id: "consistent", title: "Consistent", iconName: "repeat"),
                SurfReportOption(id: "inconsistent", title: "Inconsistent", iconName: "repeat"),
                SurfReportOption(id: "sporadic", title: "Sporadic", iconName: "repeat")
            ]
        ),
        SurfReportStep(
            title: "Wave Quality",
            description: "How well are the waves breaking?",
            options: [
                SurfReportOption(id: "mushy", title: "Mushy", iconName: "star"),
                SurfReportOption(id: "average", title: "Average", iconName: "star"),
                SurfReportOption(id: "okay", title: "Okay", iconName: "star"),
                SurfReportOption(id: "good", title: "Good", iconName: "star"),
                SurfReportOption(id: "excellent", title: "Excellent", iconName: "star")
            ]
        ),
        SurfReportStep(
            title: "Media Upload",
            description: "Upload a photo or video of current conditions (optional)",
            options: []
        ),
        SurfReportStep(
            title: "Date & Time",
            description: "When did you surf? (Uses photo/video timestamp, file date, or manual selection)",
            options: []
        )
    ]

    var currentStepTitle: String {
        steps[currentStep].title
    }

    var currentStepDescription: String {
        steps[currentStep].description
    }

    var currentStepOptions: [SurfReportOption] {
        steps[currentStep].options
    }

    var canSubmit: Bool {
        // Check if all required steps have selections (excluding photo step and date step)
        // Photo step is now at index 6, date step is at index 7, so check 0-5
        for i in 0..<6 {
            if selectedOptions[i] == nil {
                return false
            }
        }

        // Check if uploads are still in progress
        if selectedImage != nil && isUploadingImage {
            return false
        }

        if selectedVideoURL != nil && (isUploadingVideo || isUploadingVideoThumbnail) {
            return false
        }

        // Allow submission even if uploads failed - user will be notified
        return true
    }

    var shouldDisableNextButton: Bool {
        // For steps with options (0-5), require a selection
        if currentStep < 6 {
            return selectedOptions[currentStep] == nil
        }
        // For photo step (6), always allow next (photo is optional)
        // For date step (7), always allow next (date is required but can be set)
        return false
    }

    func selectOption(_ optionId: String) {
        selectedOptions[currentStep] = optionId

        // Auto-advance to next step after a short delay (excluding photo step and date step)
        // Photo step is now at index 6, date step is at index 7, so auto-advance up to step 5
        if currentStep < 6 {
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
                self.nextStep()
            }
        }
    }

    func nextStep() {
        guard currentStep < steps.count - 1 else { return }

        // If moving from photo step without a photo, reset the timestamp flag
        if currentStep == 6 && selectedImage == nil {
            photoTimestampExtracted = false
        }

        currentStep += 1

        // If we're now on the photo step and have an image but haven't started upload, start it
        if currentStep == 6 && selectedImage != nil && imageKey == nil && !isUploadingImage {
            if let spotId = spotId {
                Task {
                    await startImageUploadProcess(spotId: spotId)
                }
            }
        } else if currentStep == 6 {
            if selectedImage != nil && imageKey == nil && !isUploadingImage && spotId != nil {
                Task {
                    await startImageUploadProcess(spotId: spotId!)
                }
            }
        }
    }

    func previousStep() {
        guard currentStep > 0 else { return }
        currentStep -= 1
    }

    func clearImage() {
        selectedImage = nil
        imageSelection = nil
        photoTimestampExtracted = false
        // Reset to current time when photo is cleared
        selectedDateTime = Date()

        // Clear S3 upload state
        imageKey = nil
        uploadUrl = nil
        isUploadingImage = false
        uploadProgress = 0.0
        imageUploadFailed = false

        // Clear any image-related errors
        clearFieldError(for: "image")

        // Reset photo picker flag
        shouldShowPhotoPicker = false
    }

    func clearVideo() {
        // Clean up temporary video file
        if let videoURL = selectedVideoURL {
            cleanupTemporaryVideoFile(videoURL)
        }

        selectedVideoURL = nil
        selectedVideoThumbnail = nil
        videoSelection = nil
        photoTimestampExtracted = false
        // Reset to current time when video is cleared
        selectedDateTime = Date()

        // Clear S3 upload state
        videoKey = nil
        videoUploadUrl = nil
        videoThumbnailKey = nil
        isUploadingVideo = false
        isUploadingVideoThumbnail = false
        videoUploadProgress = 0.0
        videoUploadFailed = false

        // Clear validation state
        videoValidationPassed = false
        videoValidationError = nil
        isValidatingVideo = false

        // Clear any video-related errors
        clearFieldError(for: "video")
    }

    func clearMedia() {
        clearImage()
        clearVideo()
    }

    nonisolated private func cleanupTemporaryVideoFile(_ videoURL: URL) {
        do {
            try FileManager.default.removeItem(at: videoURL)
            // Note: logger not accessible from nonisolated context
        } catch {
            // Note: logger not accessible from nonisolated context
        }
    }

    func clearImageForRetry() {
        selectedImage = nil
        imageSelection = nil
        photoTimestampExtracted = false
        // Reset to current time when photo is cleared
        selectedDateTime = Date()

        // Clear S3 upload state
        imageKey = nil
        uploadUrl = nil
        isUploadingImage = false
        uploadProgress = 0.0

        // Clear any image-related errors
        clearFieldError(for: "image")

        // Preserve shouldShowPhotoPicker flag for retry
        // This flag will be set to true in retryImageUpload()
    }

    // MARK: - Error Handling

    @MainActor
    override func handleError(_ error: Error, context: String? = nil) {
        logger.log("Handling error in SurfReportSubmissionViewModel", level: .info, category: .general)

        let trebleError = TrebleSurfError.from(error)
        logger.logError(trebleError, context: context)

        // Use BaseViewModel's error handling
        super.handleError(error, context: context)

        // Create error presentation from the modern error system
        let presentation = ErrorPresentation(from: trebleError)
        logger.log("Error display created: \(presentation.title) - \(presentation.message)", level: .debug, category: .general)

        self.currentError = presentation
        self.errorMessage = presentation.message

        // Clear previous field errors
        self.fieldErrors.removeAll()

        // Set field-specific errors if applicable
        if let fieldName = presentation.fieldName {
            logger.log("Setting field error for: \(fieldName)", level: .debug, category: .validation)
            self.fieldErrors[fieldName] = presentation.helpText
        }

        // Show error alert
        self.showErrorAlert = true
    }

    func clearFieldError(for fieldName: String) {
        fieldErrors.removeValue(forKey: fieldName)
    }

    func clearAllErrors() {
        currentError = nil
        errorMessage = nil
        fieldErrors.removeAll()
        showErrorAlert = false
        shouldShowPhotoPicker = false
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
            await submitReport(spotId: spotId)
        }
    }

    func retryImageUpload(spotId: String) {
        // Clear errors but preserve the photo picker flag
        currentError = nil
        errorMessage = nil
        fieldErrors.removeAll()
        showErrorAlert = false

        // Clear the current image and reset image state
        clearImageForRetry()

        // Navigate back to the image step (step 6)
        currentStep = 6

        // Signal that the photo picker should be shown
        shouldShowPhotoPicker = true

        // Generate a new presigned URL for the retry
        Task {
            await preGenerateUploadURL()
        }
    }

    func continueWithFailedUploads(spotId: String) {
        // Clear the failure flags and allow submission
        imageUploadFailed = false
        videoUploadFailed = false

        // Clear any error messages
        clearAllErrors()

        // Proceed with submission
        Task {
            await submitReport(spotId: spotId)
        }
    }

    // MARK: - Image Error Handling

    /// Handles image-specific errors and provides user guidance
    @MainActor
    func handleImageError(_ error: Error) {
        logger.log("Handling image-specific error", level: .info, category: .media)

        let trebleError = TrebleSurfError.from(error)
        let presentation = ErrorPresentation(from: trebleError)

        if presentation.requiresImageRetry {
            logger.log("Image retry required - clearing image and showing guidance", level: .warning, category: .media)

            clearImage()

            self.currentError = presentation
            self.errorMessage = presentation.message
            self.fieldErrors["image"] = presentation.helpText
            self.showErrorAlert = true
        } else {
            logger.log("Not an image retry error - using standard error handling", level: .debug, category: .media)
            handleError(error, context: "Image error")
        }
    }



    @MainActor
    private func loadImage() async {
        logger.log("loadImage() called", level: .debug, category: .media)
        guard let imageSelection = imageSelection else {
            logger.log("No imageSelection available", level: .error, category: .media)
            return
        }
        logger.log("Image selection found, starting load process...", level: .debug, category: .media)

        do {
            if let data = try await imageSelection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {

                // Validate image using iOS ML before proceeding
                logger.log("Starting iOS ML validation...", level: .debug, category: .validation)
                do {
                    let isValid = try await imageValidationService.validateSurfImage(image)
                    if isValid {
                        logger.log("Image validated as surf-related", level: .debug, category: .validation)
                        self.processValidatedImage(image, imageSelection: imageSelection, data: data)
                    } else {
                        logger.log("Image not recognized as surf-related", level: .error, category: .validation)
                        self.handleImageValidationFailure()
                    }
                } catch {
                    logger.log("Validation failed: \(error)", level: .error, category: .validation)
                    self.handleImageValidationError(error)
                }
            }
        } catch {
            logger.log("Failed to load image: \(error)", level: .error, category: .media)
        }
    }

    @MainActor
    private func processValidatedImage(_ image: UIImage, imageSelection: PhotosPickerItem, data: Data) {
        logger.log("processValidatedImage() called", level: .debug, category: .media)
        selectedImage = image

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

        // Update the flag
        photoTimestampExtracted = timestampFound

        // Log final timestamp status
        if !timestampFound {
            logger.log("No timestamp found - using current time", level: .debug, category: .media)
        }

        // Start upload process regardless of timestamp status
        Task {
            // If no timestamp found in metadata, try to use file creation date as fallback
            if !timestampFound {
                if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: imageSelection) {
                    selectedDateTime = fileCreationDate
                    timestampFound = true
                    logger.log("Using file creation date as fallback: \(fileCreationDate)", level: .debug, category: .media)
                }
            }

            // If we already have a presigned URL, start upload immediately
            logger.log("Checking upload conditions:", level: .debug, category: .validation)
            logger.log("uploadUrl: \(self.uploadUrl?.prefix(50) ?? "nil")", level: .debug, category: .validation)
            logger.log("imageKey: \(self.imageKey ?? "nil")", level: .debug, category: .validation)
            logger.log("spotId: \(self.spotId ?? "nil")", level: .debug, category: .validation)

            if let uploadUrl = self.uploadUrl, let _ = self.imageKey {
                logger.log("Found presigned URL, starting S3 upload...", level: .debug, category: .network)
                do {
                    try await mediaUploadService.uploadImageToS3(uploadURL: uploadUrl, image: image)
                    logger.log("S3 upload completed successfully", level: .debug, category: .network)
                } catch {
                    logger.log("S3 upload failed: \(error)", level: .error, category: .network)

                    // Clear the keys since upload failed
                    await MainActor.run {
                        self.imageKey = nil
                        self.uploadedImageKey = nil
                        self.imageUploadFailed = true
                        self.isUploadingImage = false

                        // Handle the error properly
                        self.handleImageError(error)
                    }
                }
            } else if let spotId = self.spotId {
                logger.log("No presigned URL found, checking conditions for new upload...", level: .debug, category: .validation)
                logger.log("selectedImage: \(selectedImage != nil ? "present" : "nil")", level: .debug, category: .validation)
                logger.log("imageKey: \(imageKey ?? "nil")", level: .debug, category: .validation)
                logger.log("isUploadingImage: \(isUploadingImage)", level: .debug, category: .validation)

                // If we have an image but no upload started, try to start it now
                if selectedImage != nil && imageKey == nil && !isUploadingImage {
                    logger.log("Starting new image upload process...", level: .debug, category: .network)
                    await startImageUploadProcess(spotId: spotId)
                } else {
                    logger.log("Conditions not met for new upload", level: .error, category: .network)
                }
            } else {
                logger.log("No spotId available", level: .error, category: .network)
            }

            // Auto-advance to next step after photo is loaded (with a short delay)
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
                self.nextStep()
            }
        }
    }

    @MainActor
    private func handleImageValidationFailure() {
        clearImage()
        fieldErrors["image"] = "Please upload a photo that clearly shows surf conditions, waves, beach, or coastline."
        showErrorAlert = true
    }

    @MainActor
    private func handleImageValidationError(_ error: Error) {
        clearImage()
        fieldErrors["image"] = "Image validation failed. Please try a different photo."
        showErrorAlert = true
    }

    @MainActor
    private func loadVideo() async {
        logger.log("Starting video load process", level: .debug, category: .media)
        guard let videoSelection = videoSelection else {
            logger.log("No video selection found", level: .error, category: .media)
            return
        }

        logger.log("Video selection found, loading transferable...", level: .debug, category: .media)
        do {
            // Try loading as Data first, then convert to URL (like quick report)
            logger.log("Attempting to load video as Data...", level: .debug, category: .media)
            if let videoData = try await videoSelection.loadTransferable(type: Data.self) {
                logger.log("Video data loaded successfully, size: \(videoData.count) bytes", level: .debug, category: .media)

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
                        logger.log("Video thumbnail generated successfully", level: .debug, category: .media)
                        selectedVideoThumbnail = thumbnail
                    } else {
                        logger.log("Failed to generate video thumbnail", level: .error, category: .media)
                    }

                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        logger.log("Using video creation date: \(fileCreationDate)", level: .debug, category: .media)
                    }

                    // Log final timestamp status
                    if !timestampFound {
                        logger.log("No video timestamp found - using current time", level: .debug, category: .media)
                    }

                    // Validate video using iOS ML
                    logger.log("Starting video validation...", level: .debug, category: .validation)
                    await validateVideo(tempURL)

                    // Start video upload process
                    if let spotId = self.spotId {
                        logger.log("Starting video upload process for spotId: \(spotId)", level: .debug, category: .network)
                        await startVideoUploadProcess(spotId: spotId, videoURL: tempURL)
                    } else {
                        logger.log("No spotId available for video upload", level: .error, category: .network)
                    }
                } catch {
                    logger.log("Failed to write video data to temporary file: \(error)", level: .error, category: .media)
                }
            } else {
                logger.log("Failed to load video data from selection, trying URL approach...", level: .error, category: .media)
                // Fallback: try loading as URL directly
                if let videoURL = try await videoSelection.loadTransferable(type: URL.self) {
                    logger.log("Video URL loaded successfully via fallback: \(videoURL)", level: .debug, category: .media)
                    selectedVideoURL = videoURL

                    // Generate thumbnail
                    logger.log("Generating video thumbnail...", level: .debug, category: .media)
                    if let thumbnail = await mediaProcessingService.generateVideoThumbnail(from: videoURL) {
                        logger.log("Video thumbnail generated successfully", level: .debug, category: .media)
                        selectedVideoThumbnail = thumbnail
                    } else {
                        logger.log("Failed to generate video thumbnail", level: .error, category: .media)
                    }

                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        logger.log("Using video creation date: \(fileCreationDate)", level: .debug, category: .media)
                    }

                    // Log final timestamp status
                    if !timestampFound {
                        logger.log("No video timestamp found - using current time", level: .debug, category: .media)
                    }

                    // Validate video using iOS ML
                    logger.log("Starting video validation...", level: .debug, category: .validation)
                    await validateVideo(videoURL)

                    // Start video upload process
                    if let spotId = self.spotId {
                        logger.log("Starting video upload process for spotId: \(spotId)", level: .debug, category: .network)
                        await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
                    } else {
                        logger.log("No spotId available for video upload", level: .error, category: .network)
                    }
                } else {
                    logger.log("Failed to load video URL from selection via fallback", level: .error, category: .media)
                }
            }
        } catch {
            logger.log("Failed to load video: \(error)", level: .error, category: .media)
        }
    }

    @MainActor
    private func validateVideo(_ videoURL: URL) async {
        logger.log("Starting video validation for: \(videoURL)", level: .debug, category: .validation)
        isValidatingVideo = true
        videoValidationError = nil
        videoValidationPassed = false

        do {
            let isValid = try await imageValidationService.validateSurfVideo(videoURL)
            isValidatingVideo = false
            logger.log("Video validation completed. Valid: \(isValid)", level: .debug, category: .validation)
            videoValidationPassed = isValid
            if !isValid {
                logger.log("Video validation failed - not surf-related content", level: .error, category: .validation)
                videoValidationError = "This video doesn't appear to contain surf-related content. Please select a video that shows waves, surfers, or the ocean."
            } else {
                logger.log("Video validation passed", level: .debug, category: .validation)
            }
        } catch {
            isValidatingVideo = false
            logger.log("Video validation error: \(error)", level: .error, category: .validation)
            videoValidationPassed = false
            videoValidationError = "Failed to validate video: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func processValidatedVideo(_ videoURL: URL, videoSelection: PhotosPickerItem) {
        // Try to extract timestamp from video metadata
        Task {
            if let fileCreationDate = await mediaProcessingService.getFileCreationDate(from: videoSelection) {
                selectedDateTime = fileCreationDate
                photoTimestampExtracted = true
                logger.log("Using video creation date: \(fileCreationDate)", level: .debug, category: .media)
            }

            // Start video upload process
            if let spotId = self.spotId {
                logger.log("Starting video upload process for spotId: \(spotId)", level: .debug, category: .network)
                await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
            } else {
                logger.log("No spotId available for video upload", level: .error, category: .network)
            }

            // Auto-advance to next step after video is loaded
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_000_000_000) // 1.0 second
                self.nextStep()
            }
        }
    }

    @MainActor
    private func handleVideoValidationFailure() {
        clearVideo()
        fieldErrors["video"] = "Please upload a video that clearly shows surf conditions, waves, beach, or coastline."
        showErrorAlert = true
    }

    @MainActor
    private func handleVideoValidationError(_ error: Error) {
        clearVideo()
        fieldErrors["video"] = "Video validation failed. Please try a different video."
        showErrorAlert = true
    }

    /// Pre-generates presigned URL when user clicks "Add Photo" for better performance
    func preGenerateUploadURL() async {
        logger.log("Starting presigned URL generation...", level: .info, category: .network)
        guard let spotId = self.spotId else {
            logger.log("No spotId available", level: .error, category: .network)
            return
        }

        do {
            let uploadResponse = try await mediaUploadService.generateImageUploadURL(spotId: spotId)

            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
                self.uploadedImageKey = uploadResponse.imageKey
                logger.log("Set uploadedImageKey: \(uploadResponse.imageKey)", level: .debug, category: .media)
                logger.log("Presigned URL generation completed", level: .debug, category: .network)
            }

        } catch {
            logger.log("Failed to generate presigned URL: \(error)", level: .error, category: .network)
            // Don't show error to user since this is just optimization
        }
    }

    /// Pre-generates presigned URL when user clicks "Add Video" for better performance
    func preGenerateVideoUploadURL() async {
        logger.log("Starting presigned video URL generation...", level: .info, category: .network)
        guard let spotId = self.spotId else {
            logger.log("No spotId available", level: .error, category: .network)
            return
        }

        do {
            let uploadResponse = try await mediaUploadService.generateVideoUploadURL(spotId: spotId)

            await MainActor.run {
                self.videoUploadUrl = uploadResponse.uploadUrl
                self.videoKey = uploadResponse.videoKey
                self.uploadedVideoKey = uploadResponse.videoKey
                logger.log("Set uploadedVideoKey: \(uploadResponse.videoKey)", level: .debug, category: .media)
                logger.log("Presigned video URL generation completed", level: .debug, category: .network)
            }

        } catch {
            logger.log("Failed to generate presigned video URL: \(error)", level: .error, category: .network)
            // Don't show error to user since this is just optimization
        }
    }

    func getStepStatusColor(for index: Int) -> Color {
        if index < currentStep {
            return .blue // Completed
        } else if index == currentStep {
            return .blue // Current
        } else {
            return .gray.opacity(0.3) // Upcoming
        }
    }

    /// Starts the S3 upload process: generate URL, then upload image
    private func startImageUploadProcess() async {
        guard let image = selectedImage else { return }
        guard let spotId = self.spotId else { return }

        await generateUploadURLAndUploadImage(spotId: spotId, image: image)
    }

    /// Sets the spotId and starts image upload if an image is already selected
    func setSpotId(_ spotId: String) {
        self.spotId = spotId

        // If we already have an image selected but haven't started upload, start it now
        if selectedImage != nil && imageKey == nil && !isUploadingImage {
            Task {
                await startImageUploadProcess(spotId: spotId)
            }
        }
    }

    /// Starts the S3 upload process with a specific spotId
    func startImageUploadProcess(spotId: String) async {
        guard let image = selectedImage else {
            return
        }
        await generateUploadURLAndUploadImage(spotId: spotId, image: image)
    }

    /// Starts the S3 video upload process with a specific spotId
    func startVideoUploadProcess(spotId: String, videoURL: URL) async {
        logger.log("Starting video upload process for spotId: \(spotId)", level: .info, category: .network)

        await MainActor.run {
            isUploadingVideo = true
            videoUploadProgress = 0.0
        }

        let startTime = Date()

        do {
            // Step 1: Upload video thumbnail first (if available)
            if let thumbnail = selectedVideoThumbnail {
                logger.log("Step 1: Uploading video thumbnail...", level: .info, category: .network)
                isUploadingVideoThumbnail = true
                if let thumbnailKey = await mediaUploadService.uploadVideoThumbnail(spotId: spotId, thumbnail: thumbnail) {
                    videoThumbnailKey = thumbnailKey
                    uploadedVideoThumbnailKey = thumbnailKey
                }
                isUploadingVideoThumbnail = false
            }

            // Step 2: Generate presigned upload URL for video
            logger.log("Step 2: Generating presigned upload URL...", level: .info, category: .network)
            let uploadResponse = try await mediaUploadService.generateVideoUploadURL(spotId: spotId)

            await MainActor.run {
                self.videoUploadUrl = uploadResponse.uploadUrl
                self.videoKey = uploadResponse.videoKey
                self.uploadedVideoKey = uploadResponse.videoKey
                logger.log("Set uploadedVideoKey: \(uploadResponse.videoKey)", level: .debug, category: .media)
            }

            let urlGenerationTime = Date().timeIntervalSince(startTime)
            logger.log("Presigned URL generated in \(String(format: "%.2f", urlGenerationTime))s", level: .debug, category: .network)
            logger.log("Video key: \(uploadResponse.videoKey)", level: .debug, category: .network)
            logger.log("Upload URL: \(uploadResponse.uploadUrl.prefix(50))...", level: .debug, category: .network)

            // Step 3: Upload video to S3
            logger.log("Step 3: Uploading video to S3...", level: .info, category: .network)
            try await mediaUploadService.uploadVideoToS3(uploadURL: uploadResponse.uploadUrl, videoURL: videoURL)

            let totalTime = Date().timeIntervalSince(startTime)
            logger.log("Video upload completed successfully in \(String(format: "%.2f", totalTime))s", level: .debug, category: .network)

            await MainActor.run {
                self.isUploadingVideo = false
                self.videoUploadProgress = 1.0
            }

        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            logger.log("Video upload failed after \(String(format: "%.2f", totalTime))s", level: .error, category: .network)
            if let nsError = error as NSError? {
                logger.log("Error details - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription), User Info: \(nsError.userInfo)", level: .error, category: .network)
            }

            await MainActor.run {
                self.isUploadingVideo = false
                self.videoUploadFailed = true

                // Clear the video key since upload failed
                self.videoKey = nil

                self.handleImageError(error)
            }
        }
    }

    /// Generates presigned URL and uploads image to S3
    private func generateUploadURLAndUploadImage(spotId: String, image: UIImage) async {
        logger.log("Starting image upload process for spotId: \(spotId)", level: .info, category: .network)

        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }

        let startTime = Date()

        do {
            // Step 1: Generate presigned upload URL
            logger.log("Step 1: Generating presigned upload URL...", level: .info, category: .network)
            let uploadResponse = try await mediaUploadService.generateImageUploadURL(spotId: spotId)

            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
                self.uploadedImageKey = uploadResponse.imageKey
                logger.log("Set uploadedImageKey: \(uploadResponse.imageKey)", level: .debug, category: .media)
            }

            let urlGenerationTime = Date().timeIntervalSince(startTime)
            logger.log("Presigned URL generated in \(String(format: "%.2f", urlGenerationTime))s", level: .debug, category: .network)
            logger.log("Image key: \(uploadResponse.imageKey)", level: .debug, category: .network)
            logger.log("Upload URL: \(uploadResponse.uploadUrl.prefix(50))...", level: .debug, category: .network)

            // Step 2: Upload image to S3
            logger.log("Step 2: Uploading image to S3...", level: .info, category: .network)
            logger.log("About to call uploadImageToS3...", level: .debug, category: .network)
            try await mediaUploadService.uploadImageToS3(uploadURL: uploadResponse.uploadUrl, image: image)
            logger.log("uploadImageToS3 completed successfully", level: .debug, category: .network)

            let totalTime = Date().timeIntervalSince(startTime)
            logger.log("Image upload completed successfully in \(String(format: "%.2f", totalTime))s", level: .debug, category: .network)

            await MainActor.run {
                self.isUploadingImage = false
                self.uploadProgress = 1.0
            }

        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            logger.log("Image upload failed after \(String(format: "%.2f", totalTime))s", level: .error, category: .network)
            logger.log("Error type: \(type(of: error))", level: .error, category: .network)
            logger.log("Error description: \(error.localizedDescription)", level: .error, category: .network)
            if let nsError = error as NSError? {
                logger.log("Error details - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription), User Info: \(nsError.userInfo)", level: .error, category: .network)
            }

            await MainActor.run {
                self.isUploadingImage = false
                self.imageUploadFailed = true

                // Clear the image key since upload failed
                self.imageKey = nil

                logger.log("About to call handleImageError...", level: .error, category: .network)
                // Use the new image-specific error handling
                self.handleImageError(error)
                logger.log("handleImageError completed", level: .error, category: .network)
            }
        }
    }


    @MainActor
    func submitReport(spotId: String) async {
        logger.log("Starting surf report submission", level: .info, category: .api)

        guard canSubmit else {
            logger.log("Cannot submit - missing required fields", level: .warning, category: .validation)
            return
        }

        isSubmitting = true
        errorMessage = nil

        // Set the spotId for image uploads if not already set
        if self.spotId == nil {
            logger.log("Setting spotId for image uploads", level: .debug, category: .dataProcessing)
            setSpotId(spotId)
        }

        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            logger.log("Invalid spot format", level: .error, category: .validation)
            errorMessage = "Invalid spot format"
            showErrorAlert = true
            isSubmitting = false
            return
        }

        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        logger.log("Parsed location - Country: \(country), Region: \(region), Spot: \(spot)", level: .debug, category: .dataProcessing)

        // Convert local time to UTC before sending to backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC") // Format as UTC
        let formattedDate = dateFormatter.string(from: selectedDateTime)

        // Debug timezone information
        logger.log("Selected date (local): \(selectedDateTime)", level: .debug, category: .dataProcessing)
        logger.log("Current timezone: \(TimeZone.current.identifier)", level: .debug, category: .dataProcessing)
        logger.log("Formatted date (UTC): \(formattedDate)", level: .debug, category: .dataProcessing)

        // Check if uploads are still in progress
        if selectedImage != nil && isUploadingImage {
            logger.log("Cannot submit - image upload still in progress", level: .error, category: .validation)
            errorMessage = "Image upload is still in progress. Please wait for it to complete."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        if selectedVideoURL != nil && (isUploadingVideo || isUploadingVideoThumbnail) {
            logger.log("Cannot submit - video upload still in progress", level: .error, category: .validation)
            errorMessage = "Video upload is still in progress. Please wait for it to complete."
            showErrorAlert = true
            isSubmitting = false
            return
        }

        // Note: Upload failures are handled in the UI - if we reach here, user chose to continue

        // Determine which image key to use (regular image or video thumbnail)
        let finalImageKey: String
        if let videoThumbnailKey = videoThumbnailKey {
            // If we have a video thumbnail, use that as the image
            finalImageKey = videoThumbnailKey
        } else {
            // Otherwise use the regular image key
            finalImageKey = (!imageUploadFailed && imageKey != nil) ? imageKey! : ""
        }

        // Prepare report data - only include S3 keys if uploads succeeded
        let reportData: [String: Any] = [
            "country": country,
            "region": region,
            "spot": spot,
            "surfSize": selectedOptions[0] ?? "",
            "messiness": selectedOptions[1] ?? "",
            "windDirection": selectedOptions[2] ?? "",
            "windAmount": selectedOptions[3] ?? "",
            "consistency": selectedOptions[4] ?? "",
            "quality": selectedOptions[5] ?? "",
            "imageKey": finalImageKey,
            "videoKey": (!videoUploadFailed && videoKey != nil) ? videoKey! : "",
            "date": formattedDate
        ]

        logger.log("Report data prepared: Surf Size: \(selectedOptions[0] ?? "nil"), Messiness: \(selectedOptions[1] ?? "nil"), Wind Direction: \(selectedOptions[2] ?? "nil"), Wind Amount: \(selectedOptions[3] ?? "nil"), Consistency: \(selectedOptions[4] ?? "nil"), Quality: \(selectedOptions[5] ?? "nil")", level: .debug, category: .dataProcessing)

        // Log image and video keys separately for clarity
        if !imageUploadFailed, let key = imageKey {
            logger.log("Image Key: \(key)", level: .debug, category: .dataProcessing)
        } else {
            logger.log("Image Key: none (upload failed)", level: .debug, category: .dataProcessing)
        }

        if !videoUploadFailed, let key = videoKey {
            logger.log("Video Key: \(key)", level: .debug, category: .dataProcessing)
        } else {
            logger.log("Video Key: none (upload failed)", level: .debug, category: .dataProcessing)
        }

        logger.log("Date: \(formattedDate)", level: .debug, category: .dataProcessing)

        do {
            logger.log("Attempting to submit surf report...", level: .info, category: .api)
            try await submitSurfReport(reportData)

            logger.log("Surf report submitted successfully!", level: .debug, category: .api)
            // If we get here, submission was successful
            await MainActor.run {
                self.submissionSuccessful = true
                logger.log("Set submissionSuccessful = true", level: .debug, category: .api)
                logger.log("ViewModel instanceId: \(self.instanceId)", level: .debug, category: .api)
                self.showSuccessAlert = true
                // Clear any previous errors
                self.clearAllErrors()
                // Dismiss after a short delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    logger.log("Setting shouldDismiss = true", level: .debug, category: .ui)
                    self.shouldDismiss = true
                }
            }
        } catch {
            let trebleError = TrebleSurfError.from(error)
            logger.logError(trebleError, context: "Surf report submission")
            // Use the error handling system
            handleError(error, context: "Surf report submission")
        }

        isSubmitting = false
        logger.log("Submission process completed", level: .info, category: .api)
    }

    private func submitSurfReport(_ reportData: [String: Any]) async throws {
        // Use new iOS-validated endpoint for all submissions
        let endpoint = "/api/submitSurfReportWithIOSValidation"
        logger.log("Using endpoint: \(endpoint)", level: .debug, category: .api)

        // Add iOS validation flag to indicate this was validated client-side
        var finalReportData = reportData
        finalReportData["iosValidated"] = true

        if let uploadedImageKey = imageKey {
            logger.log("Using S3 image key: \(uploadedImageKey)", level: .debug, category: .media)
        }
        if let uploadedVideoKey = videoKey {
            logger.log("Using S3 video key: \(uploadedVideoKey)", level: .debug, category: .media)
        }
        if imageKey == nil && videoKey == nil {
            logger.log("No media data to include", level: .debug, category: .media)
        }

        // Convert to Data for APIClient
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: finalReportData)
            logger.log("JSON data prepared, size: \(jsonData.count) bytes", level: .debug, category: .dataProcessing)
        } catch {
            logger.log("Failed to serialize JSON data: \(error)", level: .error, category: .dataProcessing)
            throw error
        }

        // Always refresh CSRF token before making the request to ensure it's current
        logger.log("Refreshing CSRF token before submission...", level: .debug, category: .authentication)
        let csrfRefreshed = await apiClient.refreshCSRFToken()
        if csrfRefreshed {
            logger.log("CSRF token refreshed successfully", level: .debug, category: .authentication)
        } else {
            logger.log("CSRF token refresh failed, proceeding with existing token", level: .warning, category: .authentication)
        }

        logger.log("Making POST request to: \(endpoint)", level: .info, category: .api)

        // Use APIClient which handles CSRF tokens and session cookies automatically
        do {
            _ = try await apiClient.postRequest(to: endpoint, body: jsonData) as SurfReportSubmissionResponse
            logger.log("POST request successful", level: .debug, category: .api)
            // Clear uploaded media tracking since submission was successful
            self.uploadedImageKey = nil
            self.uploadedVideoKey = nil
            self.uploadedVideoThumbnailKey = nil
        } catch {
            logger.log("POST request failed: \(error)", level: .error, category: .api)
            if let nsError = error as NSError? {
                logger.log("Error details - Domain: \(nsError.domain), Code: \(nsError.code), Description: \(nsError.localizedDescription), User Info: \(nsError.userInfo)", level: .error, category: .api)
            }

            // If it's a 403 error, try refreshing the CSRF token and retry once
            if let nsError = error as NSError?, nsError.code == 403 {
                logger.log("403 error detected, refreshing CSRF token and retrying...", level: .warning, category: .authentication)
                let retryRefresh = await apiClient.refreshCSRFToken()
                if retryRefresh {
                    logger.log("CSRF token refreshed, retrying request...", level: .debug, category: .authentication)
                    _ = try await apiClient.postRequest(to: endpoint, body: jsonData) as SurfReportSubmissionResponse
                    logger.log("Retry request successful", level: .debug, category: .api)
                    return
                } else {
                    logger.log("CSRF token refresh failed, using original error", level: .error, category: .authentication)
                }
            }

            throw error
        }
    }

    // MARK: - Cleanup Functions

    /// Cleans up unused uploaded media when user cancels or abandons the form
    func cleanupUnusedUploads() {
        logger.log("===== CLEANUP FUNCTION CALLED =====", level: .info, category: .general)
        logger.log("ViewModel instanceId: \(instanceId)", level: .debug, category: .general)
        logger.log("submissionSuccessful = \(submissionSuccessful)", level: .debug, category: .general)
        logger.log("Call stack: \(Thread.callStackSymbols.prefix(5))", level: .debug, category: .general)

        // Don't cleanup if submission was successful - the media is now part of a report
        if submissionSuccessful {
            logger.log("Skipping cleanup - submission was successful", level: .info, category: .general)
            return
        }

        logger.log("Starting cleanup of unused uploads", level: .info, category: .general)
        logger.log("Uploaded image key: \(uploadedImageKey ?? "nil")", level: .debug, category: .general)
        logger.log("Uploaded video key: \(uploadedVideoKey ?? "nil")", level: .debug, category: .general)
        logger.log("Uploaded video thumbnail key: \(uploadedVideoThumbnailKey ?? "nil")", level: .debug, category: .general)

        Task {
            await mediaUploadService.cleanupUnusedMedia(
                imageKey: uploadedImageKey,
                videoKey: uploadedVideoKey,
                videoThumbnailKey: uploadedVideoThumbnailKey
            )
        }
    }
}
