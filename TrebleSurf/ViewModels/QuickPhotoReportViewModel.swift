import Foundation
import SwiftUI
import PhotosUI
import CoreGraphics
import UIKit
import Photos
import ImageIO

// MARK: - Quick Photo Report View Model

class QuickPhotoReportViewModel: ObservableObject {
    @Published var selectedImage: UIImage? = nil
    @Published var imageSelection: PhotosPickerItem? = nil {
        didSet {
            Task {
                await loadImage()
            }
        }
    }
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
    @Published var currentError: APIErrorHandler.ErrorDisplay?
    @Published var fieldErrors: [String: String] = [:]
    
    // S3 upload properties
    @Published var isUploadingImage = false
    @Published var uploadProgress: Double = 0.0
    @Published var imageKey: String?
    @Published var uploadUrl: String?
    
    private var spotId: String?
    
    var canSubmit: Bool {
        selectedImage != nil
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
                            print("📸 [QUICK_REPORT] Found EXIF timestamp: \(extractedDate)")
                        }
                    }
                    // Check for TIFF date
                    else if let tiff = properties["{TIFF}"] as? [String: Any],
                            let dateTime = tiff["DateTime"] as? String {
                        if let extractedDate = parseImageDate(dateTime) {
                            selectedDateTime = extractedDate
                            timestampFound = true
                            print("📸 [QUICK_REPORT] Found TIFF timestamp: \(extractedDate)")
                        }
                    }
                }
                
                // If no timestamp found in metadata, try to use file creation date as fallback
                if !timestampFound {
                    if let fileCreationDate = await getFileCreationDate(from: imageSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        print("📸 [QUICK_REPORT] Using file creation date as fallback: \(fileCreationDate)")
                    }
                }
                
                // Update the flag
                photoTimestampExtracted = timestampFound
                
                // Log final timestamp status and show timestamp selector if needed
                if !timestampFound {
                    print("📸 [QUICK_REPORT] No timestamp found - will show timestamp selector")
                    showTimestampSelector = true
                } else {
                    showTimestampSelector = false
                }
                
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
                    // No presigned URL yet, but spotId available - upload will start when URL is ready
                } else {
                    // Neither presigned URL nor spotId available
                }
            }
        } catch {
            // Failed to load image:
        }
    }
    
    /// Pre-generates presigned URL when user clicks "Add Photo" for better performance
    func preGenerateUploadURL() async {
        guard let spotId = self.spotId else {
            return
        }
        
        let startTime = Date()
        
        do {
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            let generationTime = Date().timeIntervalSince(startTime)
            
            await MainActor.run {
                self.uploadUrl = uploadResponse.uploadUrl
                self.imageKey = uploadResponse.imageKey
            }
            
        } catch {
            let generationTime = Date().timeIntervalSince(startTime)
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
                print("📸 [QUICK_REPORT] Asset identifier: \(assetIdentifier)")
                
                let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
                print("📸 [QUICK_REPORT] Fetch result count: \(fetchResult.count)")
                
                if let asset = fetchResult.firstObject {
                    print("📸 [QUICK_REPORT] PHAsset found:")
                    print("   - Creation date: \(asset.creationDate?.description ?? "nil")")
                    print("   - Modification date: \(asset.modificationDate?.description ?? "nil")")
                    print("   - Media type: \(asset.mediaType.rawValue)")
                    print("   - Media subtypes: \(asset.mediaSubtypes.rawValue)")
                    
                    // Try creation date first
                    if let creationDate = asset.creationDate {
                        print("📸 [QUICK_REPORT] Using PHAsset creation date: \(creationDate)")
                        return creationDate
                    }
                    
                    // Fallback to modification date if creation date is nil
                    if let modificationDate = asset.modificationDate {
                        print("📸 [QUICK_REPORT] Using PHAsset modification date as fallback: \(modificationDate)")
                        return modificationDate
                    }
                    
                    print("📸 [QUICK_REPORT] Both creation and modification dates are nil")
                } else {
                    print("📸 [QUICK_REPORT] No PHAsset found for identifier")
                }
            } else {
                print("📸 [QUICK_REPORT] No asset identifier available")
            }
            
            // Alternative approach: try to get the image data and check file attributes
            print("📸 [QUICK_REPORT] Trying alternative method with image data...")
            if let data = try await imageSelection.loadTransferable(type: Data.self) {
                // Try to get file creation date from the data itself
                if let imageSource = CGImageSourceCreateWithData(data as CFData, nil) {
                    if let properties = CGImageSourceCopyPropertiesAtIndex(imageSource, 0, nil) as? [String: Any] {
                        print("📸 [QUICK_REPORT] Image source properties available")
                        
                        // Check for file creation date in properties
                        if let fileCreationDate = properties["{File}"] as? [String: Any],
                           let creationDate = fileCreationDate["FileCreationDate"] as? Date {
                            print("📸 [QUICK_REPORT] Found file creation date in properties: \(creationDate)")
                            return creationDate
                        }
                        
                        // Check for file modification date
                        if let fileModificationDate = properties["{File}"] as? [String: Any],
                           let modificationDate = fileModificationDate["FileModificationDate"] as? Date {
                            print("📸 [QUICK_REPORT] Found file modification date in properties: \(modificationDate)")
                            return modificationDate
                        }
                        
                        print("📸 [QUICK_REPORT] No file dates found in image properties")
                        print("📸 [QUICK_REPORT] Available properties: \(properties.keys)")
                    }
                }
            }
            
        } catch {
            print("📸 [QUICK_REPORT] Error accessing file creation date: \(error)")
        }
        
        print("📸 [QUICK_REPORT] All methods failed to find file creation date")
        return nil
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
    
    /// Sets the spotId and starts image upload if an image is already selected
    func setSpotId(_ spotId: String) {
        self.spotId = spotId
        
        // If we already have an image selected but haven't started upload, start it now
        if selectedImage != nil && imageKey == nil && !isUploadingImage {
            Task {
                await startImageUploadProcess(spotId: spotId)
            }
        } else {
            // Not starting upload - conditions not met
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
        
        let startTime = Date()
        
        do {
            // Step 1: Generate presigned upload URL
            let uploadResponse = try await generateUploadURL(spotId: spotId)
            
            await MainActor.run {
                self.uploadProgress = 0.5
            }
            
            // Step 2: Upload image to S3
            try await uploadImageToS3(uploadURL: uploadResponse.uploadUrl, image: image)
            
            await MainActor.run {
                self.isUploadingImage = false
                self.uploadProgress = 1.0
            }
            
        } catch {
            await MainActor.run {
                self.isUploadingImage = false
                // Use the new error handling system
                self.handleError(error)
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
        
        let startTime = Date()
        let (_, response) = try await URLSession.shared.data(for: request)
        let uploadTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to S3 - Status: \(httpResponse.statusCode)"])
        }
        
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
        
        // Convert local time to UTC before sending to backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC") // Format as UTC
        let formattedDate = dateFormatter.string(from: selectedDateTime)
        
        // Debug timezone information
        print("📅 [QUICK_REPORT] Selected date (local): \(selectedDateTime)")
        print("📅 [QUICK_REPORT] Current timezone: \(TimeZone.current.identifier)")
        print("📅 [QUICK_REPORT] Formatted date (UTC): \(formattedDate)")
        
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
            "imageKey": imageKey ?? "",
            "date": formattedDate
        ]
        
        do {
            let success = try await submitSurfReport(reportData)
            
            if success {
                showSuccessAlert = true
                // Dismiss after a short delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    self.shouldDismiss = true
                }
            } else {
                // Handle submission failure
                handleError(NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to submit report"]))
            }
        } catch {
            // Use the new error handling system
            handleError(error)
        }
        
        isSubmitting = false
    }
    
    private func submitSurfReport(_ reportData: [String: Any]) async throws -> Bool {
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
        return await withCheckedContinuation { continuation in
            APIClient.shared.postRequest(to: endpoint, body: jsonData) { (result: Result<SurfReportSubmissionResponse, Error>) in
                switch result {
                case .success(let response):
                    continuation.resume(returning: true)
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
                                            continuation.resume(returning: true)
                                        case .failure(let retryError):
                                            continuation.resume(returning: false)
                                        }
                                    }
                                } else {
                                    continuation.resume(returning: false)
                                }
                            }
                            return
                        }
                    }
                    
                    continuation.resume(returning: false)
                }
            }
        }
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
}
