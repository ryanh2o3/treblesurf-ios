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
class SurfReportSubmissionViewModel: ObservableObject {
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
    @Published var currentError: APIErrorHandler.ErrorDisplay?
    @Published var fieldErrors: [String: String] = [:]
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
    
    // Nonisolated storage for video URL cleanup in deinit
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
            print("✅ [LONG_FORM_VIDEO] Cleaned up temporary video file: \(videoURL)")
        } catch {
            print("❌ [LONG_FORM_VIDEO] Failed to clean up temporary video file: \(error)")
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
    func handleError(_ error: Error) {
        print("🚨 [ERROR_HANDLER] Handling error in SurfReportSubmissionViewModel")
        print("🚨 [ERROR_HANDLER] Error: \(error)")
        
        let errorDisplay = APIErrorHandler.shared.handleAPIError(error)
        
        if let errorDisplay = errorDisplay {
            print("🚨 [ERROR_HANDLER] Error display created:")
            print("   - Title: \(errorDisplay.title)")
            print("   - Message: \(errorDisplay.message)")
            print("   - Help: \(errorDisplay.help)")
            print("   - Field Name: \(errorDisplay.fieldName ?? "nil")")
            print("   - Is Retryable: \(errorDisplay.isRetryable)")
            print("   - Requires Auth: \(errorDisplay.requiresAuthentication)")
            print("   - Requires Image Retry: \(errorDisplay.requiresImageRetry)")
        } else {
            print("⚠️ [ERROR_HANDLER] No error display created - using generic error handling")
        }
        
        self.currentError = errorDisplay
        self.errorMessage = errorDisplay?.message
        
        // Clear previous field errors
        self.fieldErrors.removeAll()
        
        // Set field-specific errors if applicable
        if let errorDisplay = errorDisplay, let fieldName = errorDisplay.fieldName {
            print("🏷️ [ERROR_HANDLER] Setting field error for: \(fieldName)")
            self.fieldErrors[fieldName] = errorDisplay.help
        }
        
        // Show error alert
        print("🚨 [ERROR_HANDLER] Showing error alert to user")
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
        print("📷 [IMAGE_ERROR] Handling image-specific error")
        print("📷 [IMAGE_ERROR] Error: \(error)")
        
        let errorDisplay = APIErrorHandler.shared.handleAPIError(error)
        
        if let errorDisplay = errorDisplay, errorDisplay.requiresImageRetry {
            print("📷 [IMAGE_ERROR] Image retry required - clearing image and showing guidance")
            print("📷 [IMAGE_ERROR] Error display:")
            print("   - Title: \(errorDisplay.title)")
            print("   - Message: \(errorDisplay.message)")
            print("   - Help: \(errorDisplay.help)")
            
            // For image validation errors, clear the image and show guidance
            clearImage()
            
            // Set the error for display
            self.currentError = errorDisplay
            self.errorMessage = errorDisplay.message
            
            // Set field error for image
            self.fieldErrors["image"] = errorDisplay.help
            
            // Show error alert
            self.showErrorAlert = true
        } else {
            print("📷 [IMAGE_ERROR] Not an image retry error - using standard error handling")
            // Handle other types of errors normally
            handleError(error)
        }
    }
    

    
    @MainActor
    private func loadImage() async {
        print("📷 [LOAD_IMAGE] loadImage() called")
        guard let imageSelection = imageSelection else { 
            print("❌ [LOAD_IMAGE] No imageSelection available")
            return 
        }
        print("📷 [LOAD_IMAGE] Image selection found, starting load process...")
        
        do {
            if let data = try await imageSelection.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                
                // Validate image using iOS ML before proceeding
                print("🔍 [IMAGE_VALIDATION] Starting iOS ML validation...")
                ImageValidationService.shared.validateSurfImage(image) { result in
                    Task { @MainActor in
                        switch result {
                        case .success(let isValid):
                            if isValid {
                                print("✅ [IMAGE_VALIDATION] Image validated as surf-related")
                                self.processValidatedImage(image, imageSelection: imageSelection, data: data)
                            } else {
                                print("❌ [IMAGE_VALIDATION] Image not recognized as surf-related")
                                self.handleImageValidationFailure()
                            }
                        case .failure(let error):
                            print("❌ [IMAGE_VALIDATION] Validation failed: \(error)")
                            self.handleImageValidationError(error)
                        }
                    }
                }
            }
        } catch {
            print("❌ [IMAGE_LOAD] Failed to load image: \(error)")
        }
    }
    
    @MainActor
    private func processValidatedImage(_ image: UIImage, imageSelection: PhotosPickerItem, data: Data) {
        print("📷 [PROCESS_VALIDATED] processValidatedImage() called")
        selectedImage = image
        
        // Try to extract timestamp from image metadata
        var timestampFound = false
        if let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
           let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
            
            // Check for EXIF date
            if let exif = properties["{Exif}"] as? [String: Any],
               let dateTimeOriginal = exif["DateTimeOriginal"] as? String {
                if let extractedDate = parseImageDate(dateTimeOriginal) {
                    selectedDateTime = extractedDate
                    timestampFound = true
                    print("📸 [IMAGE_TIMESTAMP] Found EXIF timestamp: \(extractedDate)")
                }
            }
            // Check for TIFF date
            else if let tiff = properties["{TIFF}"] as? [String: Any],
                    let dateTime = tiff["DateTime"] as? String {
                if let extractedDate = parseImageDate(dateTime) {
                    selectedDateTime = extractedDate
                    timestampFound = true
                    print("📸 [IMAGE_TIMESTAMP] Found TIFF timestamp: \(extractedDate)")
                }
            }
        }
        
        // Update the flag
        photoTimestampExtracted = timestampFound
        
        // Log final timestamp status
        if !timestampFound {
            print("📸 [IMAGE_TIMESTAMP] No timestamp found - using current time")
        }
        
        // Start upload process regardless of timestamp status
        Task {
            // If no timestamp found in metadata, try to use file creation date as fallback
            if !timestampFound {
                if let fileCreationDate = await getFileCreationDate(from: imageSelection) {
                    selectedDateTime = fileCreationDate
                    timestampFound = true
                    print("📸 [IMAGE_TIMESTAMP] Using file creation date as fallback: \(fileCreationDate)")
                }
            }
            
            // If we already have a presigned URL, start upload immediately
            print("🔍 [UPLOAD_CHECK] Checking upload conditions:")
            print("🔍 [UPLOAD_CHECK] uploadUrl: \(self.uploadUrl?.prefix(50) ?? "nil")")
            print("🔍 [UPLOAD_CHECK] imageKey: \(self.imageKey ?? "nil")")
            print("🔍 [UPLOAD_CHECK] spotId: \(self.spotId ?? "nil")")
            
            if let uploadUrl = self.uploadUrl, let imageKey = self.imageKey {
                print("✅ [UPLOAD_CHECK] Found presigned URL, starting S3 upload...")
                do {
                    try await uploadImageToS3(uploadURL: uploadUrl, image: image)
                    print("✅ [UPLOAD_CHECK] S3 upload completed successfully")
                } catch {
                    print("❌ [UPLOAD_CHECK] S3 upload failed: \(error)")
                    
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
                print("🔍 [UPLOAD_CHECK] No presigned URL found, checking conditions for new upload...")
                print("🔍 [UPLOAD_CHECK] selectedImage: \(selectedImage != nil ? "present" : "nil")")
                print("🔍 [UPLOAD_CHECK] imageKey: \(imageKey ?? "nil")")
                print("🔍 [UPLOAD_CHECK] isUploadingImage: \(isUploadingImage)")
                
                // If we have an image but no upload started, try to start it now
                if selectedImage != nil && imageKey == nil && !isUploadingImage && spotId != nil {
                    print("✅ [UPLOAD_CHECK] Starting new image upload process...")
                    await startImageUploadProcess(spotId: spotId)
                } else {
                    print("❌ [UPLOAD_CHECK] Conditions not met for new upload")
                }
            } else {
                print("❌ [UPLOAD_CHECK] No spotId available")
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
        print("🎬 [LONG_FORM_VIDEO] Starting video load process")
        guard let videoSelection = videoSelection else {
            print("❌ [LONG_FORM_VIDEO] No video selection found")
            return
        }
        
        print("🎬 [LONG_FORM_VIDEO] Video selection found, loading transferable...")
        do {
            // Try loading as Data first, then convert to URL (like quick report)
            print("🎬 [LONG_FORM_VIDEO] Attempting to load video as Data...")
            if let videoData = try await videoSelection.loadTransferable(type: Data.self) {
                print("✅ [LONG_FORM_VIDEO] Video data loaded successfully, size: \(videoData.count) bytes")
                
                // Create a temporary file URL
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileName = "temp_video_\(UUID().uuidString).mov"
                let tempURL = tempDirectory.appendingPathComponent(tempFileName)
                
                do {
                    try videoData.write(to: tempURL)
                    print("✅ [LONG_FORM_VIDEO] Video data written to temporary file: \(tempURL)")
                    selectedVideoURL = tempURL
                    
                    // Generate thumbnail
                    print("🎬 [LONG_FORM_VIDEO] Generating video thumbnail...")
                    if let thumbnail = await generateVideoThumbnail(from: tempURL) {
                        print("✅ [LONG_FORM_VIDEO] Video thumbnail generated successfully")
                        selectedVideoThumbnail = thumbnail
                    } else {
                        print("❌ [LONG_FORM_VIDEO] Failed to generate video thumbnail")
                    }
                    
                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        print("🎥 [LONG_FORM_VIDEO] Using video creation date: \(fileCreationDate)")
                    }
                    
                    // Log final timestamp status
                    if !timestampFound {
                        print("🎥 [LONG_FORM_VIDEO] No video timestamp found - using current time")
                    }
                    
                    // Validate video using iOS ML
                    print("🎬 [LONG_FORM_VIDEO] Starting video validation...")
                    await validateVideo(tempURL)
                    
                    // Start video upload process
                    if let spotId = self.spotId {
                        print("🎬 [LONG_FORM_VIDEO] Starting video upload process for spotId: \(spotId)")
                        await startVideoUploadProcess(spotId: spotId, videoURL: tempURL)
                    } else {
                        print("❌ [LONG_FORM_VIDEO] No spotId available for video upload")
                    }
                } catch {
                    print("❌ [LONG_FORM_VIDEO] Failed to write video data to temporary file: \(error)")
                }
            } else {
                print("❌ [LONG_FORM_VIDEO] Failed to load video data from selection, trying URL approach...")
                // Fallback: try loading as URL directly
                if let videoURL = try await videoSelection.loadTransferable(type: URL.self) {
                    print("✅ [LONG_FORM_VIDEO] Video URL loaded successfully via fallback: \(videoURL)")
                    selectedVideoURL = videoURL
                    
                    // Generate thumbnail
                    print("🎬 [LONG_FORM_VIDEO] Generating video thumbnail...")
                    if let thumbnail = await generateVideoThumbnail(from: videoURL) {
                        print("✅ [LONG_FORM_VIDEO] Video thumbnail generated successfully")
                        selectedVideoThumbnail = thumbnail
                    } else {
                        print("❌ [LONG_FORM_VIDEO] Failed to generate video thumbnail")
                    }
                    
                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        print("🎥 [LONG_FORM_VIDEO] Using video creation date: \(fileCreationDate)")
                    }
                    
                    // Log final timestamp status
                    if !timestampFound {
                        print("🎥 [LONG_FORM_VIDEO] No video timestamp found - using current time")
                    }
                    
                    // Validate video using iOS ML
                    print("🎬 [LONG_FORM_VIDEO] Starting video validation...")
                    await validateVideo(videoURL)
                    
                    // Start video upload process
                    if let spotId = self.spotId {
                        print("🎬 [LONG_FORM_VIDEO] Starting video upload process for spotId: \(spotId)")
                        await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
                    } else {
                        print("❌ [LONG_FORM_VIDEO] No spotId available for video upload")
                    }
                } else {
                    print("❌ [LONG_FORM_VIDEO] Failed to load video URL from selection via fallback")
                }
            }
        } catch {
            print("❌ [LONG_FORM_VIDEO] Failed to load video: \(error)")
        }
    }
    
    @MainActor
    private func validateVideo(_ videoURL: URL) async {
        print("🎬 [LONG_FORM_VIDEO] Starting video validation for: \(videoURL)")
        isValidatingVideo = true
        videoValidationError = nil
        videoValidationPassed = false
        
        ImageValidationService.shared.validateSurfVideo(videoURL) { [weak self] result in
            Task { @MainActor in
                self?.isValidatingVideo = false
                
                switch result {
                case .success(let isValid):
                    print("🎬 [LONG_FORM_VIDEO] Video validation completed. Valid: \(isValid)")
                    self?.videoValidationPassed = isValid
                    if !isValid {
                        print("❌ [LONG_FORM_VIDEO] Video validation failed - not surf-related content")
                        self?.videoValidationError = "This video doesn't appear to contain surf-related content. Please select a video that shows waves, surfers, or the ocean."
                    } else {
                        print("✅ [LONG_FORM_VIDEO] Video validation passed")
                    }
                case .failure(let error):
                    print("❌ [LONG_FORM_VIDEO] Video validation error: \(error)")
                    self?.videoValidationPassed = false
                    self?.videoValidationError = "Failed to validate video: \(error.localizedDescription)"
                }
            }
        }
    }
    
    @MainActor
    private func processValidatedVideo(_ videoURL: URL, videoSelection: PhotosPickerItem) {
        // Try to extract timestamp from video metadata
        Task {
            if let fileCreationDate = await getFileCreationDate(from: videoSelection) {
                selectedDateTime = fileCreationDate
                photoTimestampExtracted = true
                print("🎥 [VIDEO_TIMESTAMP] Using video creation date: \(fileCreationDate)")
            }
            
            // Start video upload process
            if let spotId = self.spotId {
                print("🎥 [VIDEO_UPLOAD] Starting video upload process for spotId: \(spotId)")
                await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
            } else {
                print("❌ [VIDEO_UPLOAD] No spotId available for video upload")
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
    
    private func generateVideoThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: CMTime.zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            print("❌ [VIDEO_THUMBNAIL] Failed to generate thumbnail: \(error)")
            return nil
        }
    }
    
    /// Pre-generates presigned URL when user clicks "Add Photo" for better performance
    func preGenerateUploadURL() async {
        print("🔗 [PRE_GENERATE] Starting presigned URL generation...")
        guard let spotId = self.spotId else {
            print("❌ [PRE_GENERATE] No spotId available")
            return
        }
        
        do {
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
                self.uploadedImageKey = uploadResponse.imageKey
                print("📷 [UPLOAD_TRACKING] Set uploadedImageKey: \(uploadResponse.imageKey)")
                print("✅ [PRE_GENERATE] Presigned URL generation completed")
            }
            
        } catch {
            print("❌ [PRE_GENERATE] Failed to generate presigned URL: \(error)")
            // Don't show error to user since this is just optimization
        }
    }
    
    /// Pre-generates presigned URL when user clicks "Add Video" for better performance
    func preGenerateVideoUploadURL() async {
        print("🎬 [PRE_GENERATE_VIDEO] Starting presigned video URL generation...")
        guard let spotId = self.spotId else {
            print("❌ [PRE_GENERATE_VIDEO] No spotId available")
            return
        }
        
        do {
            let uploadResponse = try await generateVideoUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.videoUploadUrl = uploadResponse.uploadUrl
                self.videoKey = uploadResponse.videoKey
                self.uploadedVideoKey = uploadResponse.videoKey
                print("🎬 [UPLOAD_TRACKING] Set uploadedVideoKey: \(uploadResponse.videoKey)")
                print("✅ [PRE_GENERATE_VIDEO] Presigned video URL generation completed")
            }
            
        } catch {
            print("❌ [PRE_GENERATE_VIDEO] Failed to generate presigned video URL: \(error)")
            // Don't show error to user since this is just optimization
        }
    }
    
    // Parse image date from various formats
    private func parseImageDate(_ dateString: String) -> Date? {
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
    
    // Attempt to get file creation date as fallback when EXIF/TIFF data is not available
    private func getFileCreationDate(from imageSelection: PhotosPickerItem) async -> Date? {
        do {
            // Try to load the asset identifier to access PHAsset
            if let assetIdentifier = imageSelection.itemIdentifier {
                print("📸 [IMAGE_TIMESTAMP] Asset identifier: \(assetIdentifier)")
                
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                print("📸 [IMAGE_TIMESTAMP] Fetch result count: \(fetchResult.count)")
                
                if let asset = fetchResult.firstObject {
                    print("📸 [IMAGE_TIMESTAMP] PHAsset found:")
                    print("   - Creation date: \(asset.creationDate?.description ?? "nil")")
                    print("   - Modification date: \(asset.modificationDate?.description ?? "nil")")
                    print("   - Media type: \(asset.mediaType.rawValue)")
                    print("   - Media subtypes: \(asset.mediaSubtypes.rawValue)")
                    
                    // Try creation date first
                    if let creationDate = asset.creationDate {
                        print("📸 [IMAGE_TIMESTAMP] Using PHAsset creation date: \(creationDate)")
                        return creationDate
                    }
                    
                    // Fallback to modification date if creation date is nil
                    if let modificationDate = asset.modificationDate {
                        print("📸 [IMAGE_TIMESTAMP] Using PHAsset modification date as fallback: \(modificationDate)")
                        return modificationDate
                    }
                    
                    print("📸 [IMAGE_TIMESTAMP] Both creation and modification dates are nil")
                } else {
                    print("📸 [IMAGE_TIMESTAMP] No PHAsset found for identifier")
                }
            } else {
                print("📸 [IMAGE_TIMESTAMP] No asset identifier available")
            }
            
            // Alternative approach: try to get the image data and check file attributes
            print("📸 [IMAGE_TIMESTAMP] Trying alternative method with image data...")
            if let data = try await imageSelection.loadTransferable(type: Data.self) {
                // Try to get file creation date from the data itself
                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
                    if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                        print("📸 [IMAGE_TIMESTAMP] Image source properties available")
                        
                        // Check for file creation date in properties
                        if let fileCreationDate = properties["{File}"] as? [String: Any],
                           let creationDate = fileCreationDate["FileCreationDate"] as? Date {
                            print("📸 [IMAGE_TIMESTAMP] Found file creation date in properties: \(creationDate)")
                            return creationDate
                        }
                        
                        // Check for file modification date
                        if let fileModificationDate = properties["{File}"] as? [String: Any],
                           let modificationDate = fileModificationDate["FileModificationDate"] as? Date {
                            print("📸 [IMAGE_TIMESTAMP] Found file modification date in properties: \(modificationDate)")
                            return modificationDate
                        }
                        
                        print("📸 [IMAGE_TIMESTAMP] No file dates found in image properties")
                        print("📸 [IMAGE_TIMESTAMP] Available properties: \(properties.keys)")
                    }
                }
            }
            
        } catch {
            print("📸 [IMAGE_TIMESTAMP] Error accessing file creation date: \(error)")
        }
        
        print("📸 [IMAGE_TIMESTAMP] All methods failed to find file creation date")
        return nil
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
    
    /// Compresses image to under 1MB while maintaining quality for surf reports
    private func compressImageForUpload(_ image: UIImage?) -> String? {
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
        
        return imageData?.base64EncodedString()
    }
    
    /// Compresses image to under 1MB and returns raw Data for S3 upload
    private func compressImageForUploadRaw(_ image: UIImage?) -> Data? {
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
    
    /// Resizes image to target dimensions while maintaining aspect ratio
    private func resizeImage(_ image: UIImage, targetSize: CGSize) -> UIImage {
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
        print("🎥 [VIDEO_UPLOAD] Starting video upload process for spotId: \(spotId)")
        
        await MainActor.run {
            isUploadingVideo = true
            videoUploadProgress = 0.0
        }
        
        let startTime = Date()
        
        do {
            // Step 1: Upload video thumbnail first (if available)
            if let thumbnail = selectedVideoThumbnail {
                print("🎥 [VIDEO_UPLOAD] Step 1: Uploading video thumbnail...")
                await uploadVideoThumbnail(spotId: spotId, thumbnail: thumbnail)
            }
            
            // Step 2: Generate presigned upload URL for video
            print("🔗 [VIDEO_UPLOAD] Step 2: Generating presigned upload URL...")
            let uploadResponse = try await generateVideoUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.videoUploadUrl = uploadResponse.uploadUrl
                self.videoKey = uploadResponse.videoKey
                self.uploadedVideoKey = uploadResponse.videoKey
                print("🎥 [UPLOAD_TRACKING] Set uploadedVideoKey: \(uploadResponse.videoKey)")
            }
            
            let urlGenerationTime = Date().timeIntervalSince(startTime)
            print("✅ [VIDEO_UPLOAD] Presigned URL generated in \(String(format: "%.2f", urlGenerationTime))s")
            print("🔑 [VIDEO_UPLOAD] Video key: \(uploadResponse.videoKey)")
            print("🌐 [VIDEO_UPLOAD] Upload URL: \(uploadResponse.uploadUrl.prefix(50))...")
            
            // Step 3: Upload video to S3
            print("☁️ [VIDEO_UPLOAD] Step 3: Uploading video to S3...")
            try await uploadVideoToS3(uploadURL: uploadResponse.uploadUrl, videoURL: videoURL)
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("✅ [VIDEO_UPLOAD] Video upload completed successfully in \(String(format: "%.2f", totalTime))s")
            
            await MainActor.run {
                self.isUploadingVideo = false
                self.videoUploadProgress = 1.0
            }
            
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            print("❌ [VIDEO_UPLOAD] Video upload failed after \(String(format: "%.2f", totalTime))s")
            print("❌ [VIDEO_UPLOAD] Error details:")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - Description: \(nsError.localizedDescription)")
                if let userInfo = nsError.userInfo as? [String: Any] {
                    print("   - User Info: \(userInfo)")
                }
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
        print("📷 [IMAGE_UPLOAD] Starting image upload process for spotId: \(spotId)")
        
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }
        
        let startTime = Date()
        
        do {
            // Step 1: Generate presigned upload URL
            print("🔗 [IMAGE_UPLOAD] Step 1: Generating presigned upload URL...")
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
                self.uploadedImageKey = uploadResponse.imageKey
                print("📷 [UPLOAD_TRACKING] Set uploadedImageKey: \(uploadResponse.imageKey)")
            }
            
            let urlGenerationTime = Date().timeIntervalSince(startTime)
            print("✅ [IMAGE_UPLOAD] Presigned URL generated in \(String(format: "%.2f", urlGenerationTime))s")
            print("🔑 [IMAGE_UPLOAD] Image key: \(uploadResponse.imageKey)")
            print("🌐 [IMAGE_UPLOAD] Upload URL: \(uploadResponse.uploadUrl.prefix(50))...")
            
            // Step 2: Upload image to S3
            print("☁️ [IMAGE_UPLOAD] Step 2: Uploading image to S3...")
            print("☁️ [IMAGE_UPLOAD] About to call uploadImageToS3...")
            try await uploadImageToS3(uploadURL: uploadResponse.uploadUrl, image: image)
            print("☁️ [IMAGE_UPLOAD] uploadImageToS3 completed successfully")
            
            let totalTime = Date().timeIntervalSince(startTime)
            print("✅ [IMAGE_UPLOAD] Image upload completed successfully in \(String(format: "%.2f", totalTime))s")
            
            await MainActor.run {
                self.isUploadingImage = false
                self.uploadProgress = 1.0
            }
            
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            print("❌ [IMAGE_UPLOAD] Image upload failed after \(String(format: "%.2f", totalTime))s")
            print("❌ [IMAGE_UPLOAD] Error details:")
            print("❌ [IMAGE_UPLOAD] Error type: \(type(of: error))")
            print("❌ [IMAGE_UPLOAD] Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - Description: \(nsError.localizedDescription)")
                if let userInfo = nsError.userInfo as? [String: Any] {
                    print("   - User Info: \(userInfo)")
                }
            }
            
            await MainActor.run {
                self.isUploadingImage = false
                self.imageUploadFailed = true
                
                // Clear the image key since upload failed
                self.imageKey = nil
                
                print("❌ [IMAGE_UPLOAD] About to call handleImageError...")
                // Use the new image-specific error handling
                self.handleImageError(error)
                print("❌ [IMAGE_UPLOAD] handleImageError completed")
            }
        }
    }
    
    /// Generates presigned upload URL from backend
    private func generateUploadURL(spotId: String) async throws -> PresignedUploadResponse {
        print("🔗 [IMAGE_UPLOAD] Generating presigned upload URL for spotId: \(spotId)")
        
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            print("❌ [IMAGE_UPLOAD] Invalid spot format: \(spotId)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid spot format"])
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        let endpoint = "/api/generateImageUploadURL?country=\(country)&region=\(region)&spot=\(spot)"
        print("🌐 [IMAGE_UPLOAD] Requesting presigned URL from: \(endpoint)")
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(endpoint) { (result: Result<PresignedUploadResponse, Error>) in
                switch result {
                case .success(let response):
                    print("✅ [IMAGE_UPLOAD] Presigned URL response received")
                    print("🔑 [IMAGE_UPLOAD] Image key: \(response.imageKey)")
                    print("🌐 [IMAGE_UPLOAD] Upload URL: \(response.uploadUrl.prefix(50))...")
                    print("⏰ [IMAGE_UPLOAD] Expires at: \(response.expiresAt)")
                    continuation.resume(returning: response)
                case .failure(let error):
                    print("❌ [IMAGE_UPLOAD] Failed to generate presigned URL: \(error)")
                    print("❌ [IMAGE_UPLOAD] Error details:")
                    if let nsError = error as NSError? {
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - Description: \(nsError.localizedDescription)")
                        if let userInfo = nsError.userInfo as? [String: Any] {
                            print("   - User Info: \(userInfo)")
                        }
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Uploads image to S3 using presigned URL
    private func uploadImageToS3(uploadURL: String, image: UIImage) async throws {
        print("☁️ [IMAGE_UPLOAD] Starting S3 upload process")
        print("☁️ [IMAGE_UPLOAD] Function called with URL: \(uploadURL.prefix(50))...")
        print("☁️ [IMAGE_UPLOAD] Image size: \(image.size)")
        
        guard let url = URL(string: uploadURL) else {
            print("❌ [IMAGE_UPLOAD] Invalid upload URL: \(uploadURL)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }
        
        // Compress image for upload - get raw JPEG data, not base64 string
        print("🗜️ [IMAGE_UPLOAD] Compressing image for upload...")
        guard let imageData = compressImageForUploadRaw(image) else {
            print("❌ [IMAGE_UPLOAD] Failed to compress image")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        print("📦 [IMAGE_UPLOAD] Image compressed to \(imageData.count) bytes")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        request.timeoutInterval = 30 // 30 second timeout
        request.allowsCellularAccess = true // Allow cellular fallback
        
        print("🚀 [IMAGE_UPLOAD] Sending PUT request to S3...")
        print("📋 [IMAGE_UPLOAD] Request headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("   \(key): \(value)")
        }
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [IMAGE_UPLOAD] Invalid response from S3 - not HTTPURLResponse")
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        print("📊 [IMAGE_UPLOAD] S3 response status code: \(httpResponse.statusCode)")
        print("📋 [IMAGE_UPLOAD] Response headers:")
        for (key, value) in httpResponse.allHeaderFields {
            print("   \(key): \(value)")
        }
        
        if !data.isEmpty {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [IMAGE_UPLOAD] Response body: \(responseString)")
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [IMAGE_UPLOAD] S3 upload failed with status: \(httpResponse.statusCode)")
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to S3 - Status: \(httpResponse.statusCode)"])
        }
        
        print("✅ [IMAGE_UPLOAD] Image successfully uploaded to S3")
    }
    
    /// Generates presigned upload URL for video from backend
    private func generateVideoUploadURL(spotId: String) async throws -> PresignedVideoUploadResponse {
        print("🔗 [VIDEO_UPLOAD] Generating presigned upload URL for spotId: \(spotId)")
        
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            print("❌ [VIDEO_UPLOAD] Invalid spot format: \(spotId)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid spot format"])
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        let endpoint = "/api/generateVideoUploadURL?country=\(country)&region=\(region)&spot=\(spot)"
        print("🌐 [VIDEO_UPLOAD] Requesting presigned URL from: \(endpoint)")
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(endpoint) { (result: Result<PresignedVideoUploadResponse, Error>) in
                switch result {
                case .success(let response):
                    print("✅ [VIDEO_UPLOAD] Presigned URL response received")
                    print("🔑 [VIDEO_UPLOAD] Video key: \(response.videoKey)")
                    print("🌐 [VIDEO_UPLOAD] Upload URL: \(response.uploadUrl.prefix(50))...")
                    continuation.resume(returning: response)
                case .failure(let error):
                    print("❌ [VIDEO_UPLOAD] Failed to generate presigned URL: \(error)")
                    print("❌ [VIDEO_UPLOAD] Error details:")
                    if let nsError = error as NSError? {
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - Description: \(nsError.localizedDescription)")
                        if let userInfo = nsError.userInfo as? [String: Any] {
                            print("   - User Info: \(userInfo)")
                        }
                    }
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Uploads video to S3 using presigned URL
    private func uploadVideoToS3(uploadURL: String, videoURL: URL) async throws {
        print("☁️ [VIDEO_UPLOAD] Starting S3 upload process")
        print("🌐 [VIDEO_UPLOAD] Upload URL: \(uploadURL.prefix(50))...")
        
        guard let url = URL(string: uploadURL) else {
            print("❌ [VIDEO_UPLOAD] Invalid upload URL: \(uploadURL)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }
        
        // Read video data
        print("📦 [VIDEO_UPLOAD] Reading video data...")
        let videoData: Data
        do {
            videoData = try Data(contentsOf: videoURL)
        } catch {
            print("❌ [VIDEO_UPLOAD] Failed to read video data: \(error)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to read video data"])
        }
        
        print("📦 [VIDEO_UPLOAD] Video data size: \(videoData.count) bytes")
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
        request.httpBody = videoData
        request.timeoutInterval = 60 // 60 second timeout for larger video files
        request.allowsCellularAccess = true // Allow cellular fallback
        
        print("🚀 [VIDEO_UPLOAD] Sending PUT request to S3...")
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [VIDEO_UPLOAD] Invalid response from S3 - not HTTPURLResponse")
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        print("📊 [VIDEO_UPLOAD] S3 response status code: \(httpResponse.statusCode)")
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [VIDEO_UPLOAD] S3 upload failed with status: \(httpResponse.statusCode)")
            if let responseHeaders = httpResponse.allHeaderFields as? [String: String] {
                print("📋 [VIDEO_UPLOAD] Response headers: \(responseHeaders)")
            }
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload video to S3 - Status: \(httpResponse.statusCode)"])
        }
        
        print("✅ [VIDEO_UPLOAD] Video successfully uploaded to S3")
    }
    
    private func uploadVideoThumbnail(spotId: String, thumbnail: UIImage) async {
        print("🎥 [VIDEO_THUMBNAIL] Starting video thumbnail upload...")
        isUploadingVideoThumbnail = true
        
        do {
            // Generate presigned URL for image upload
            let imageUploadResponse = try await generateUploadURL(spotId: spotId)
            videoThumbnailKey = imageUploadResponse.imageKey
            uploadedVideoThumbnailKey = imageUploadResponse.imageKey
            print("✅ [VIDEO_THUMBNAIL] Video thumbnail upload URL generated: \(imageUploadResponse.imageKey)")
            
            // Compress and upload the thumbnail
            if let thumbnailData = compressImageForUploadRaw(thumbnail) {
                try await uploadImageToS3(uploadURL: imageUploadResponse.uploadUrl, imageData: thumbnailData)
                print("✅ [VIDEO_THUMBNAIL] Video thumbnail uploaded successfully")
            } else {
                print("❌ [VIDEO_THUMBNAIL] Failed to compress video thumbnail")
            }
        } catch {
            print("❌ [VIDEO_THUMBNAIL] Failed to upload video thumbnail: \(error)")
        }
        
        isUploadingVideoThumbnail = false
    }
    
    private func uploadImageToS3(uploadURL: String, imageData: Data) async throws {
        print("🎥 [VIDEO_THUMBNAIL] Uploading image data to S3...")
        
        guard let url = URL(string: uploadURL) else {
            print("❌ [VIDEO_THUMBNAIL] Invalid upload URL: \(uploadURL)")
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
            print("🎥 [VIDEO_THUMBNAIL] S3 image upload response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image upload failed with status: \(httpResponse.statusCode)"])
            }
        }
    }

    
    @MainActor
    func submitReport(spotId: String) async {
        print("🏄‍♂️ [SURF_REPORT] Starting surf report submission for spotId: \(spotId)")
        
        guard canSubmit else { 
            print("❌ [SURF_REPORT] Cannot submit - missing required fields")
            return 
        }
        
        isSubmitting = true
        errorMessage = nil
        
        // Set the spotId for image uploads if not already set
        if self.spotId == nil {
            print("📝 [SURF_REPORT] Setting spotId for image uploads")
            setSpotId(spotId)
        }
        
        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            print("❌ [SURF_REPORT] Invalid spot format: \(spotId)")
            errorMessage = "Invalid spot format"
            showErrorAlert = true
            isSubmitting = false
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        print("📍 [SURF_REPORT] Parsed location - Country: \(country), Region: \(region), Spot: \(spot)")
        
        // Convert local time to UTC before sending to backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC") // Format as UTC
        let formattedDate = dateFormatter.string(from: selectedDateTime)
        
        // Debug timezone information
        print("📅 [SURF_REPORT] Selected date (local): \(selectedDateTime)")
        print("📅 [SURF_REPORT] Current timezone: \(TimeZone.current.identifier)")
        print("📅 [SURF_REPORT] Formatted date (UTC): \(formattedDate)")
        
        // Check if uploads are still in progress
        if selectedImage != nil && isUploadingImage {
            print("❌ [SURF_REPORT] Cannot submit - image upload still in progress")
            errorMessage = "Image upload is still in progress. Please wait for it to complete."
            showErrorAlert = true
            isSubmitting = false
            return
        }
        
        if selectedVideoURL != nil && (isUploadingVideo || isUploadingVideoThumbnail) {
            print("❌ [SURF_REPORT] Cannot submit - video upload still in progress")
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
        
        print("📊 [SURF_REPORT] Report data prepared:")
        print("   - Surf Size: \(selectedOptions[0] ?? "nil")")
        print("   - Messiness: \(selectedOptions[1] ?? "nil")")
        print("   - Wind Direction: \(selectedOptions[2] ?? "nil")")
        print("   - Wind Amount: \(selectedOptions[3] ?? "nil")")
        print("   - Consistency: \(selectedOptions[4] ?? "nil")")
        print("   - Quality: \(selectedOptions[5] ?? "nil")")
        print("   - Image Key: \((!imageUploadFailed && imageKey != nil) ? imageKey! : "none (upload failed)")")
        print("   - Video Key: \((!videoUploadFailed && videoKey != nil) ? videoKey! : "none (upload failed)")")
        print("   - Date: \(formattedDate)")
        
        do {
            print("🚀 [SURF_REPORT] Attempting to submit surf report...")
            try await submitSurfReport(reportData)
            
            print("✅ [SURF_REPORT] Surf report submitted successfully!")
            // If we get here, submission was successful
            await MainActor.run {
                self.submissionSuccessful = true
                print("🏆 [SURF_REPORT] Set submissionSuccessful = true")
                print("🏆 [SURF_REPORT] ViewModel instanceId: \(self.instanceId)")
                self.showSuccessAlert = true
                // Clear any previous errors
                self.clearAllErrors()
                // Dismiss after a short delay
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 1_500_000_000) // 1.5 seconds
                    print("🚪 [SURF_REPORT] Setting shouldDismiss = true")
                    self.shouldDismiss = true
                }
            }
        } catch {
            print("❌ [SURF_REPORT] Error during submission: \(error)")
            print("❌ [SURF_REPORT] Error details:")
            if let nsError = error as NSError? {
                print("   - Domain: \(nsError.domain)")
                print("   - Code: \(nsError.code)")
                print("   - Description: \(nsError.localizedDescription)")
                if let userInfo = nsError.userInfo as? [String: Any] {
                    print("   - User Info: \(userInfo)")
                }
            }
            // Use the new error handling system
            handleError(error)
        }
        
        isSubmitting = false
        print("🏁 [SURF_REPORT] Submission process completed")
    }
    
    private func submitSurfReport(_ reportData: [String: Any]) async throws {
        // Use new iOS-validated endpoint for all submissions
        let endpoint = "/api/submitSurfReportWithIOSValidation"
        print("🌐 [SURF_REPORT] Using endpoint: \(endpoint)")
        
        // Add iOS validation flag to indicate this was validated client-side
        var finalReportData = reportData
        finalReportData["iosValidated"] = true
        
        if imageKey != nil {
            print("📷 [SURF_REPORT] Using S3 image key: \(imageKey!)")
        }
        if videoKey != nil {
            print("🎥 [SURF_REPORT] Using S3 video key: \(videoKey!)")
        }
        if imageKey == nil && videoKey == nil {
            print("📷 [SURF_REPORT] No media data to include")
        }
        
        // Convert to Data for APIClient
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: finalReportData)
            print("📦 [SURF_REPORT] JSON data prepared, size: \(jsonData.count) bytes")
        } catch {
            print("❌ [SURF_REPORT] Failed to serialize JSON data: \(error)")
            throw error
        }
        
        // Always refresh CSRF token before making the request to ensure it's current
        print("🔄 [SURF_REPORT] Refreshing CSRF token before submission...")
        await withCheckedContinuation { continuation in
            APIClient.shared.refreshCSRFToken { success in
                if success {
                    print("✅ [SURF_REPORT] CSRF token refreshed successfully: \(AuthManager.shared.csrfToken?.prefix(10) ?? "nil")...")
                } else {
                    print("⚠️ [SURF_REPORT] CSRF token refresh failed, proceeding with existing token")
                }
                continuation.resume()
            }
        }
        
        print("🚀 [SURF_REPORT] Making POST request to: \(endpoint)")
        
        // Use APIClient which handles CSRF tokens and session cookies automatically
        try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.postRequest(to: endpoint, body: jsonData) { (result: Result<SurfReportSubmissionResponse, Error>) in
                switch result {
                case .success(let response):
                    print("✅ [SURF_REPORT] POST request successful")
                    // Clear uploaded media tracking since submission was successful
                    self.uploadedImageKey = nil
                    self.uploadedVideoKey = nil
                    self.uploadedVideoThumbnailKey = nil
                    continuation.resume()
                case .failure(let error):
                    print("❌ [SURF_REPORT] POST request failed: \(error)")
                    print("❌ [SURF_REPORT] Error details:")
                    if let nsError = error as NSError? {
                        print("   - Domain: \(nsError.domain)")
                        print("   - Code: \(nsError.code)")
                        print("   - Description: \(nsError.localizedDescription)")
                        if let userInfo = nsError.userInfo as? [String: Any] {
                            print("   - User Info: \(userInfo)")
                        }
                    }
                    
                    // If it's a 403 error, try refreshing the CSRF token and retry once
                    if let nsError = error as NSError? {
                        if nsError.code == 403 {
                            print("🔄 [SURF_REPORT] 403 error detected, refreshing CSRF token and retrying...")
                            APIClient.shared.refreshCSRFToken { success in
                                if success {
                                    print("✅ [SURF_REPORT] CSRF token refreshed, retrying request...")
                                    // Retry the request
                                    APIClient.shared.postRequest(to: endpoint, body: jsonData) { (retryResult: Result<SurfReportSubmissionResponse, Error>) in
                                        switch retryResult {
                                        case .success(let response):
                                            print("✅ [SURF_REPORT] Retry request successful")
                                            continuation.resume()
                                        case .failure(let retryError):
                                            print("❌ [SURF_REPORT] Retry request failed: \(retryError)")
                                            print("❌ [SURF_REPORT] Retry error details:")
                                            if let retryNsError = retryError as NSError? {
                                                print("   - Domain: \(retryNsError.domain)")
                                                print("   - Code: \(retryNsError.code)")
                                                print("   - Description: \(retryNsError.localizedDescription)")
                                                if let retryUserInfo = retryNsError.userInfo as? [String: Any] {
                                                    print("   - User Info: \(retryUserInfo)")
                                                }
                                            }
                                            continuation.resume(throwing: retryError)
                                        }
                                    }
                                } else {
                                    print("❌ [SURF_REPORT] CSRF token refresh failed, using original error")
                                    continuation.resume(throwing: error)
                                }
                            }
                            return
                        }
                    }
                    
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    // MARK: - Cleanup Functions
    
    /// Cleans up unused uploaded media when user cancels or abandons the form
    func cleanupUnusedUploads() {
        print("🧹 [CLEANUP] ===== CLEANUP FUNCTION CALLED =====")
        print("🧹 [CLEANUP] ViewModel instanceId: \(instanceId)")
        print("🧹 [CLEANUP] submissionSuccessful = \(submissionSuccessful)")
        print("🧹 [CLEANUP] Call stack: \(Thread.callStackSymbols.prefix(5))")
        
        // Don't cleanup if submission was successful - the media is now part of a report
        if submissionSuccessful {
            print("🧹 [CLEANUP] Skipping cleanup - submission was successful")
            return
        }
        
        print("🧹 [CLEANUP] Starting cleanup of unused uploads")
        print("🧹 [CLEANUP] Uploaded image key: \(uploadedImageKey ?? "nil")")
        print("🧹 [CLEANUP] Uploaded video key: \(uploadedVideoKey ?? "nil")")
        print("🧹 [CLEANUP] Uploaded video thumbnail key: \(uploadedVideoThumbnailKey ?? "nil")")
        
        Task {
            await cleanupUnusedMedia()
        }
    }
    
    /// Cleans up unused media by calling backend delete endpoints
    private func cleanupUnusedMedia() async {
        var cleanupTasks: [Task<Void, Never>] = []
        
        // Clean up any uploaded image (since user is canceling, it's unused)
        if let uploadedImageKey = uploadedImageKey {
            print("🧹 [CLEANUP] Scheduling cleanup for uploaded image: \(uploadedImageKey)")
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: uploadedImageKey, type: "image")
            })
        }
        
        // Clean up any uploaded video (since user is canceling, it's unused)
        if let uploadedVideoKey = uploadedVideoKey {
            print("🧹 [CLEANUP] Scheduling cleanup for uploaded video: \(uploadedVideoKey)")
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: uploadedVideoKey, type: "video")
            })
        }
        
        // Clean up any uploaded video thumbnail (since user is canceling, it's unused)
        if let uploadedThumbnailKey = uploadedVideoThumbnailKey {
            print("🧹 [CLEANUP] Scheduling cleanup for uploaded video thumbnail: \(uploadedThumbnailKey)")
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: uploadedThumbnailKey, type: "image")
            })
        }
        
        // Wait for all cleanup tasks to complete
        await withTaskGroup(of: Void.self) { group in
            for task in cleanupTasks {
                group.addTask { await task.value }
            }
        }
        
        print("🧹 [CLEANUP] Unused media cleanup completed")
    }
    
    /// Deletes a specific uploaded media file from S3
    private func deleteUploadedMedia(key: String, type: String) async {
        print("🗑️ [CLEANUP] Deleting unused \(type): \(key)")
        
        do {
            let endpoint = "/api/deleteUploadedMedia?key=\(key)&type=\(type)"
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                APIClient.shared.makeFlexibleRequest(to: endpoint, method: "DELETE", requiresAuth: true) { (result: Result<EmptyResponse, Error>) in
                    switch result {
                    case .success:
                        print("✅ [CLEANUP] Successfully deleted \(type): \(key)")
                        continuation.resume()
                    case .failure(let error):
                        print("❌ [CLEANUP] Failed to delete \(type) \(key): \(error)")
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            print("❌ [CLEANUP] Error deleting \(type) \(key): \(error)")
        }
    }
}
