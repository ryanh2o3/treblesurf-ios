import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics
import UIKit



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



class SurfReportSubmissionViewModel: ObservableObject {
    @Published var currentStep = 0
    @Published var selectedOptions: [Int: String] = [:]
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
    @Published var selectedImage: UIImage? = nil
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
    
    // New properties for S3 upload workflow
    @Published var isUploadingImage = false
    @Published var uploadProgress: Double = 0.0
    @Published var imageKey: String?
    @Published var uploadUrl: String?
    
    // Store the spotId for image uploads
    private var spotId: String?
    
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
            title: "Photo Upload",
            description: "Upload a photo of current conditions (optional)",
            options: []
        ),
        SurfReportStep(
            title: "Date & Time",
            description: "When did you surf? (Use photo timestamp or pick manually)",
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
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
        
        // Clear any image-related errors
        clearFieldError(for: "image")
        
        // Reset photo picker flag
        shouldShowPhotoPicker = false
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
        let errorDisplay = APIErrorHandler.shared.handleAPIError(error)
        
        self.currentError = errorDisplay
        self.errorMessage = errorDisplay?.message
        
        // Clear previous field errors
        self.fieldErrors.removeAll()
        
        // Set field-specific errors if applicable
        if let errorDisplay = errorDisplay, let fieldName = errorDisplay.fieldName {
            self.fieldErrors[fieldName] = errorDisplay.help
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
    
    // MARK: - Image Error Handling
    
    /// Handles image-specific errors and provides user guidance
    @MainActor
    func handleImageError(_ error: Error) {
        let errorDisplay = APIErrorHandler.shared.handleAPIError(error)
        
        if let errorDisplay = errorDisplay, errorDisplay.requiresImageRetry {
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
            // Handle other types of errors normally
            handleError(error)
        }
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
                        }
                    }
                    // Check for TIFF date
                    else if let tiff = properties["{TIFF}"] as? [String: Any],
                            let dateTime = tiff["DateTime"] as? String {
                        if let extractedDate = parseImageDate(dateTime) {
                            selectedDateTime = extractedDate
                            timestampFound = true
                        }
                    }
                }
                
                // Update the flag
                photoTimestampExtracted = timestampFound
                
                // If we already have a presigned URL, start upload immediately
                if let uploadUrl = self.uploadUrl, let imageKey = self.imageKey {
                    Task {
                        do {
                            try await uploadImageToS3(uploadURL: uploadUrl, image: image)
                        } catch {
                            // Could show error to user here if needed
                        }
                    }
                } else if let spotId = self.spotId {
                    // If we have an image but no upload started, try to start it now
                    if selectedImage != nil && imageKey == nil && !isUploadingImage && spotId != nil {
                        Task {
                            await startImageUploadProcess(spotId: spotId)
                        }
                    }
                }
                
                // Auto-advance to next step after photo is loaded (with a short delay)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    self.nextStep()
                }
            }
        } catch {
        }
    }
    
    /// Pre-generates presigned URL when user clicks "Add Photo" for better performance
    func preGenerateUploadURL() async {
        guard let spotId = self.spotId else {
            return
        }
        
        do {
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
            }
            
        } catch {
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
    
    /// Generates presigned URL and uploads image to S3
    private func generateUploadURLAndUploadImage(spotId: String, image: UIImage) async {
        await MainActor.run {
            isUploadingImage = true
            uploadProgress = 0.0
        }
        
        let startTime = Date()
        
        do {
            // Step 1: Generate presigned upload URL
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
            }
            
            let urlGenerationTime = Date().timeIntervalSince(startTime)
            
            // Step 2: Upload image to S3
            try await uploadImageToS3(uploadURL: uploadResponse.uploadUrl, image: image)
            
            let totalTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.isUploadingImage = false
                self.uploadProgress = 1.0
            }
            
        } catch {
            let totalTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.isUploadingImage = false
                
                // Use the new image-specific error handling
                self.handleImageError(error)
            }
        }
    }
    
    /// Generates presigned upload URL from backend
    private func generateUploadURL(spotId: String) async throws -> PresignedUploadResponse {
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid spot format"])
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        let endpoint = "/api/generateImageUploadURL?country=\(country)&region=\(region)&spot=\(spot)"
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(endpoint) { (result: Result<PresignedUploadResponse, Error>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: response)
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Uploads image to S3 using presigned URL
    private func uploadImageToS3(uploadURL: String, image: UIImage) async throws {
        guard let url = URL(string: uploadURL) else {
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }
        
        // Compress image for upload - get raw JPEG data, not base64 string
        guard let imageData = compressImageForUploadRaw(image) else {
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Failed to compress image"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to S3 - Status: \(httpResponse.statusCode)"])
        }
    }
    

    
    @MainActor
    func submitReport(spotId: String) async {
        guard canSubmit else { return }
        
        isSubmitting = true
        errorMessage = nil
        
        // Set the spotId for image uploads if not already set
        if self.spotId == nil {
            setSpotId(spotId)
        }
        
        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            errorMessage = "Invalid spot format"
            showErrorAlert = true
            isSubmitting = false
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        // Format the selected date for the API
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let formattedDate = dateFormatter.string(from: selectedDateTime)
        
        // Prepare report data - use S3 image key if available, fallback to base64
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
            "imageKey": imageKey ?? "",
            "date": formattedDate
        ]
        
        do {
            try await submitSurfReport(reportData)
            
            // If we get here, submission was successful
            showSuccessAlert = true
            // Clear any previous errors
            clearAllErrors()
            // Dismiss after a short delay
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                self.shouldDismiss = true
            }
        } catch {
            // Use the new error handling system
            handleError(error)
        }
        
        isSubmitting = false
    }
    
    private func submitSurfReport(_ reportData: [String: Any]) async throws {
        // Use new S3 endpoint if we have an image key, fallback to legacy endpoint
        let endpoint = imageKey != nil ? "/api/submitSurfReportWithS3Image" : "/api/submitSurfReport"
        
        // If using legacy endpoint, add base64 image data
        var finalReportData = reportData
        if imageKey == nil, let image = selectedImage {
            finalReportData["imageData"] = compressImageForUpload(image) ?? ""
        }
        

        
        // Convert to Data for APIClient
        let jsonData: Data
        do {
            jsonData = try JSONSerialization.data(withJSONObject: finalReportData)
        } catch {
            throw error
        }
        
        // Check if we have a CSRF token, refresh if needed
        if AuthManager.shared.csrfToken == nil {
            await withCheckedContinuation { continuation in
                APIClient.shared.refreshCSRFToken { success in
                    continuation.resume()
                }
            }
        }
        
        // Use APIClient which handles CSRF tokens and session cookies automatically
        try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.postRequest(to: endpoint, body: jsonData) { (result: Result<SurfReportSubmissionResponse, Error>) in
                switch result {
                case .success(let response):
                    continuation.resume()
                case .failure(let error):
                    // If it's a 403 error, try refreshing the CSRF token and retry once
                    if let nsError = error as NSError? {
                        if nsError.code == 403 {
                            APIClient.shared.refreshCSRFToken { success in
                                if success {
                                    // Retry the request
                                    APIClient.shared.postRequest(to: endpoint, body: jsonData) { (retryResult: Result<SurfReportSubmissionResponse, Error>) in
                                        switch retryResult {
                                        case .success(let response):
                                            continuation.resume()
                                        case .failure(let retryError):
                                            continuation.resume(throwing: retryError)
                                        }
                                    }
                                } else {
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
}
