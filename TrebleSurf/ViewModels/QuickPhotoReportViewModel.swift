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
class QuickPhotoReportViewModel: ObservableObject {
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
            print("🎬 [QUICK_VIDEO] Video selection changed: \(selectedVideo != nil ? "Selected" : "Nil")")
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
    @Published var currentError: APIErrorHandler.ErrorDisplay?
    @Published var fieldErrors: [String: String] = [:]
    
    // Track submission success to avoid cleanup after successful submission
    @Published var submissionSuccessful = false
    
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
    
    // Nonisolated storage for video URL cleanup in deinit
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
        
        ImageValidationService.shared.validateSurfImage(image) { [weak self] result in
            Task { @MainActor in
                self?.isValidatingImage = false
                
                switch result {
                case .success(let isValid):
                    self?.imageValidationPassed = isValid
                    if !isValid {
                        self?.imageValidationError = "This image doesn't appear to contain surf-related content. Please select a photo that shows waves, surfers, or the ocean."
                    }
                case .failure(let error):
                    self?.imageValidationPassed = false
                    self?.imageValidationError = "Failed to validate image: \(error.localizedDescription)"
                }
            }
        }
    }
    
    @MainActor
    private func loadVideo() async {
        print("🎬 [QUICK_VIDEO] Starting video load process")
        guard let videoSelection = selectedVideo else {
            print("❌ [QUICK_VIDEO] No video selection found")
            return
        }
        
        print("🎬 [QUICK_VIDEO] Video selection found, loading transferable...")
        do {
            // Try loading as Data first, then convert to URL
            print("🎬 [QUICK_VIDEO] Attempting to load video as Data...")
            if let videoData = try await videoSelection.loadTransferable(type: Data.self) {
                print("✅ [QUICK_VIDEO] Video data loaded successfully, size: \(videoData.count) bytes")
                
                // Create a temporary file URL
                let tempDirectory = FileManager.default.temporaryDirectory
                let tempFileName = "temp_video_\(UUID().uuidString).mov"
                let tempURL = tempDirectory.appendingPathComponent(tempFileName)
                
                do {
                    try videoData.write(to: tempURL)
                    print("✅ [QUICK_VIDEO] Video data written to temporary file: \(tempURL)")
                    selectedVideoURL = tempURL
                    
                    // Generate thumbnail
                    print("🎬 [QUICK_VIDEO] Generating video thumbnail...")
                    if let thumbnail = await generateVideoThumbnail(from: tempURL) {
                        print("✅ [QUICK_VIDEO] Video thumbnail generated successfully")
                        selectedVideoThumbnail = thumbnail
                    } else {
                        print("❌ [QUICK_VIDEO] Failed to generate video thumbnail")
                    }
                    
                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        print("🎥 [QUICK_VIDEO] Using video creation date: \(fileCreationDate)")
                    }
                    
                    // Update timestamp selector visibility
                    if !timestampFound {
                        print("🎥 [QUICK_VIDEO] No video timestamp found - will show timestamp selector")
                        showTimestampSelector = true
                    } else {
                        showTimestampSelector = false
                    }
                    
                    // Validate video using iOS ML
                    print("🎬 [QUICK_VIDEO] Starting video validation...")
                    await validateVideo(tempURL)
                    
                    // Start video upload process
                    if let spotId = self.spotId {
                        print("🎬 [QUICK_VIDEO] Starting video upload process for spotId: \(spotId)")
                        await startVideoUploadProcess(spotId: spotId, videoURL: tempURL)
                    } else {
                        print("❌ [QUICK_VIDEO] No spotId available for video upload")
                    }
                } catch {
                    print("❌ [QUICK_VIDEO] Failed to write video data to temporary file: \(error)")
                }
            } else {
                print("❌ [QUICK_VIDEO] Failed to load video data from selection, trying URL approach...")
                // Fallback: try loading as URL directly
                if let videoURL = try await videoSelection.loadTransferable(type: URL.self) {
                    print("✅ [QUICK_VIDEO] Video URL loaded successfully via fallback: \(videoURL)")
                    selectedVideoURL = videoURL
                    
                    // Generate thumbnail
                    print("🎬 [QUICK_VIDEO] Generating video thumbnail...")
                    if let thumbnail = await generateVideoThumbnail(from: videoURL) {
                        print("✅ [QUICK_VIDEO] Video thumbnail generated successfully")
                        selectedVideoThumbnail = thumbnail
                    } else {
                        print("❌ [QUICK_VIDEO] Failed to generate video thumbnail")
                    }
                    
                    // Try to extract timestamp from video metadata
                    var timestampFound = false
                    if let fileCreationDate = await getFileCreationDate(from: videoSelection) {
                        selectedDateTime = fileCreationDate
                        timestampFound = true
                        photoTimestampExtracted = true
                        print("🎥 [QUICK_VIDEO] Using video creation date: \(fileCreationDate)")
                    }
                    
                    // Update timestamp selector visibility
                    if !timestampFound {
                        print("🎥 [QUICK_VIDEO] No video timestamp found - will show timestamp selector")
                        showTimestampSelector = true
                    } else {
                        showTimestampSelector = false
                    }
                    
                    // Validate video using iOS ML
                    print("🎬 [QUICK_VIDEO] Starting video validation...")
                    await validateVideo(videoURL)
                    
                    // Start video upload process
                    if let spotId = self.spotId {
                        print("🎬 [QUICK_VIDEO] Starting video upload process for spotId: \(spotId)")
                        await startVideoUploadProcess(spotId: spotId, videoURL: videoURL)
                    } else {
                        print("❌ [QUICK_VIDEO] No spotId available for video upload")
                    }
                } else {
                    print("❌ [QUICK_VIDEO] Failed to load video URL from selection via fallback")
                }
            }
        } catch {
            print("❌ [QUICK_VIDEO] Failed to load video: \(error)")
        }
    }
    
    @MainActor
    private func validateVideo(_ videoURL: URL) async {
        print("🎬 [QUICK_VIDEO] Starting video validation for: \(videoURL)")
        isValidatingVideo = true
        videoValidationError = nil
        videoValidationPassed = false
        
        ImageValidationService.shared.validateSurfVideo(videoURL) { [weak self] result in
            Task { @MainActor in
                self?.isValidatingVideo = false
                
                switch result {
                case .success(let isValid):
                    print("🎬 [QUICK_VIDEO] Video validation completed. Valid: \(isValid)")
                    self?.videoValidationPassed = isValid
                    if !isValid {
                        print("❌ [QUICK_VIDEO] Video validation failed - not surf-related content")
                        self?.videoValidationError = "This video doesn't appear to contain surf-related content. Please select a video that shows waves, surfers, or the ocean."
                    } else {
                        print("✅ [QUICK_VIDEO] Video validation passed")
                    }
                case .failure(let error):
                    print("❌ [QUICK_VIDEO] Video validation error: \(error)")
                    self?.videoValidationPassed = false
                    self?.videoValidationError = "Failed to validate video: \(error.localizedDescription)"
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from videoURL: URL) async -> UIImage? {
        let asset = AVURLAsset(url: videoURL)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        imageGenerator.maximumSize = CGSize(width: 300, height: 300)
        
        let time = CMTime(seconds: 1, preferredTimescale: 60)
        
        do {
            if #available(iOS 18.0, *) {
                let (cgImage, _) = try await imageGenerator.image(at: time)
                return UIImage(cgImage: cgImage)
            } else {
                let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
                return UIImage(cgImage: cgImage)
            }
        } catch {
            print("Failed to generate video thumbnail: \(error)")
            return nil
        }
    }
    
    private func startVideoUploadProcess(spotId: String, videoURL: URL) async {
        print("🎬 [QUICK_VIDEO] Starting video upload process for spotId: \(spotId)")
        do {
            // First, upload the video thumbnail as an image
            if let thumbnail = selectedVideoThumbnail {
                print("🎬 [QUICK_VIDEO] Uploading video thumbnail as image...")
                await uploadVideoThumbnail(spotId: spotId, thumbnail: thumbnail)
            }
            
            // Then upload the video
            print("🎬 [QUICK_VIDEO] Generating presigned upload URL for video...")
            let videoUploadResponse = try await generateVideoUploadURL(spotId: spotId)
            videoUploadUrl = videoUploadResponse.uploadUrl
            videoKey = videoUploadResponse.videoKey
            print("✅ [QUICK_VIDEO] Presigned URL generated. Key: \(videoUploadResponse.videoKey)")
            
            // Start video upload
            print("🎬 [QUICK_VIDEO] Starting S3 video upload...")
            try await uploadVideoToS3(uploadURL: videoUploadResponse.uploadUrl, videoURL: videoURL)
            print("✅ [QUICK_VIDEO] Video upload completed successfully")
        } catch {
            print("❌ [QUICK_VIDEO] Failed to start video upload process: \(error)")
        }
    }
    
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
                    print("✅ [VIDEO_UPLOAD] Presigned URL generated successfully")
                    continuation.resume(returning: response)
                case .failure(let error):
                    print("❌ [VIDEO_UPLOAD] Failed to generate presigned URL: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func uploadVideoToS3(uploadURL: String, videoURL: URL) async throws {
        print("🎬 [QUICK_VIDEO] Starting S3 upload to: \(uploadURL)")
        isUploadingVideo = true
        videoUploadProgress = 0.0
        
        do {
            print("🎬 [QUICK_VIDEO] Reading video data from: \(videoURL)")
            let videoData = try Data(contentsOf: videoURL)
            print("🎬 [QUICK_VIDEO] Video data size: \(videoData.count) bytes")
            
            guard let url = URL(string: uploadURL) else {
                print("❌ [QUICK_VIDEO] Invalid upload URL: \(uploadURL)")
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
            }
            
            var request = URLRequest(url: url)
            request.httpMethod = "PUT"
            request.setValue("video/mp4", forHTTPHeaderField: "Content-Type")
            request.httpBody = videoData
            
            print("🎬 [QUICK_VIDEO] Sending PUT request to S3...")
            let (_, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("🎬 [QUICK_VIDEO] S3 response status: \(httpResponse.statusCode)")
                if httpResponse.statusCode == 200 {
                    videoUploadProgress = 1.0
                    print("✅ [QUICK_VIDEO] Video uploaded successfully to S3")
                } else {
                    print("❌ [QUICK_VIDEO] S3 upload failed with status: \(httpResponse.statusCode)")
                    throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Upload failed with status: \(httpResponse.statusCode)"])
                }
            } else {
                print("❌ [QUICK_VIDEO] Invalid HTTP response")
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
            }
        } catch {
            print("❌ [QUICK_VIDEO] S3 upload error: \(error)")
            throw error
        }
        
        isUploadingVideo = false
        print("🎬 [QUICK_VIDEO] Upload process completed")
    }
    
    private func uploadVideoThumbnail(spotId: String, thumbnail: UIImage) async {
        print("🎬 [QUICK_VIDEO] Starting video thumbnail upload...")
        isUploadingVideoThumbnail = true
        
        do {
            // Generate presigned URL for image upload
            let imageUploadResponse = try await generateImageUploadURL(spotId: spotId)
            videoThumbnailKey = imageUploadResponse.imageKey
            print("✅ [QUICK_VIDEO] Video thumbnail upload URL generated: \(imageUploadResponse.imageKey)")
            
            // Compress and upload the thumbnail
            if let thumbnailData = compressImageForUploadRaw(thumbnail) {
                try await uploadImageToS3(uploadURL: imageUploadResponse.uploadUrl, imageData: thumbnailData)
                print("✅ [QUICK_VIDEO] Video thumbnail uploaded successfully")
            } else {
                print("❌ [QUICK_VIDEO] Failed to compress video thumbnail")
            }
        } catch {
            print("❌ [QUICK_VIDEO] Failed to upload video thumbnail: \(error)")
        }
        
        isUploadingVideoThumbnail = false
    }
    
    private func generateImageUploadURL(spotId: String) async throws -> PresignedUploadResponse {
        print("🔗 [VIDEO_THUMBNAIL] Generating presigned upload URL for spotId: \(spotId)")
        
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            print("❌ [VIDEO_THUMBNAIL] Invalid spot format: \(spotId)")
            throw NSError(domain: "SurfReport", code: 400, userInfo: [NSLocalizedDescriptionKey: "Invalid spot format"])
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        let endpoint = "/api/generateImageUploadURL?country=\(country)&region=\(region)&spot=\(spot)"
        print("🌐 [VIDEO_THUMBNAIL] Requesting presigned URL from: \(endpoint)")
        
        return try await withCheckedThrowingContinuation { continuation in
            APIClient.shared.request(endpoint) { (result: Result<PresignedUploadResponse, Error>) in
                switch result {
                case .success(let response):
                    print("✅ [VIDEO_THUMBNAIL] Presigned URL generated successfully")
                    continuation.resume(returning: response)
                case .failure(let error):
                    print("❌ [VIDEO_THUMBNAIL] Failed to generate presigned URL: \(error)")
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    private func uploadImageToS3(uploadURL: String, imageData: Data) async throws {
        print("🎬 [QUICK_VIDEO] Uploading image data to S3...")
        
        guard let url = URL(string: uploadURL) else {
            print("❌ [QUICK_VIDEO] Invalid upload URL: \(uploadURL)")
            throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid upload URL"])
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "PUT"
        request.setValue("image/jpeg", forHTTPHeaderField: "Content-Type")
        request.httpBody = imageData
        
        let (_, response) = try await URLSession.shared.data(for: request)
        
        if let httpResponse = response as? HTTPURLResponse {
            print("🎬 [QUICK_VIDEO] S3 image upload response status: \(httpResponse.statusCode)")
            if httpResponse.statusCode != 200 {
                throw NSError(domain: "VideoUpload", code: 0, userInfo: [NSLocalizedDescriptionKey: "Image upload failed with status: \(httpResponse.statusCode)"])
            }
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
            print("✅ [QUICK_VIDEO] Cleaned up temporary video file: \(videoURL)")
        } catch {
            print("❌ [QUICK_VIDEO] Failed to clean up temporary video file: \(error)")
        }
    }
    
    func clearMedia() {
        clearImage()
        clearVideo()
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
    
    /// Sets the spotId and starts image/video upload if media is already selected
    func setSpotId(_ spotId: String) {
        print("🎬 [QUICK_VIDEO] Setting spotId: \(spotId)")
        self.spotId = spotId
        
        // If we already have an image selected but haven't started upload, start it now
        if selectedImage != nil && imageKey == nil && !isUploadingImage {
            print("🎬 [QUICK_VIDEO] Starting image upload for existing selection")
            Task {
                await startImageUploadProcess(spotId: spotId)
            }
        }
        
        // If we already have a video selected but haven't started upload, start it now
        if selectedVideoURL != nil && videoKey == nil && !isUploadingVideo {
            print("🎬 [QUICK_VIDEO] Starting video upload for existing selection")
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
        
        print("🚀 [QUICK_UPLOAD] Sending PUT request to S3...")
        print("📋 [QUICK_UPLOAD] Request headers:")
        for (key, value) in request.allHTTPHeaderFields ?? [:] {
            print("   \(key): \(value)")
        }
        
        let startTime = Date()
        let (data, response) = try await URLSession.shared.data(for: request)
        let uploadTime = Date().timeIntervalSince(startTime)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            print("❌ [QUICK_UPLOAD] Invalid response from S3 - not HTTPURLResponse")
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid response from S3"])
        }
        
        print("📊 [QUICK_UPLOAD] S3 response status code: \(httpResponse.statusCode)")
        print("📋 [QUICK_UPLOAD] Response headers:")
        for (key, value) in httpResponse.allHeaderFields {
            print("   \(key): \(value)")
        }
        
        if !data.isEmpty {
            if let responseString = String(data: data, encoding: .utf8) {
                print("📄 [QUICK_UPLOAD] Response body: \(responseString)")
            }
        }
        
        guard httpResponse.statusCode == 200 else {
            print("❌ [QUICK_UPLOAD] S3 upload failed with status: \(httpResponse.statusCode)")
            throw NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to upload image to S3 - Status: \(httpResponse.statusCode)"])
        }
        
        print("✅ [QUICK_UPLOAD] Image successfully uploaded to S3 in \(String(format: "%.2f", uploadTime))s")
        
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
        print("🎬 [QUICK_VIDEO] Parsing spotId: \(spotId)")
        let components = spotId.split(separator: "#")
        print("🎬 [QUICK_VIDEO] SpotId components: \(components)")
        guard components.count >= 3 else {
            print("❌ [QUICK_VIDEO] Invalid spot format - not enough components")
            errorMessage = "Invalid spot format"
            showErrorAlert = true
            isSubmitting = false
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        print("🎬 [QUICK_VIDEO] Parsed - Country: \(country), Region: \(region), Spot: \(spot)")
        
        // Convert local time to UTC before sending to backend
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        dateFormatter.timeZone = TimeZone(abbreviation: "UTC") // Format as UTC
        let formattedDate = dateFormatter.string(from: selectedDateTime)
        
        // Debug timezone information
        print("📅 [QUICK_REPORT] Selected date (local): \(selectedDateTime)")
        print("📅 [QUICK_REPORT] Current timezone: \(TimeZone.current.identifier)")
        print("📅 [QUICK_REPORT] Formatted date (UTC): \(formattedDate)")
        
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
                handleError(NSError(domain: "SurfReport", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to submit report"]))
            }
        } catch {
            // Use the new error handling system
            handleError(error)
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
        print("🎬 [QUICK_VIDEO] Final report data being sent:")
        for (key, value) in finalReportData {
            print("🎬 [QUICK_VIDEO]   \(key): \(value)")
        }
        
        // Check if we have any media keys
        print("🎬 [QUICK_VIDEO] Media keys - Image: \(imageKey ?? "nil"), Video: \(videoKey ?? "nil")")
        
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
                case .success:
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
                                        case .success:
                                            continuation.resume(returning: true)
                                        case .failure:
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
    
    // MARK: - Cleanup Functions
    
    /// Cleans up unused uploaded media when user dismisses the form
    func cleanupUnusedUploads() {
        // Don't cleanup if submission was successful - the media is now part of a report
        if submissionSuccessful {
            print("🧹 [CLEANUP] Skipping cleanup - submission was successful")
            return
        }
        
        print("🧹 [CLEANUP] Cleaning up unused uploads after cancellation")
        Task {
            await cleanupUnusedMedia()
        }
    }
    
    /// Cleans up unused media by calling backend delete endpoints
    private func cleanupUnusedMedia() async {
        var cleanupTasks: [Task<Void, Never>] = []
        
        // Clean up any uploaded image (since user is dismissing, it's unused)
        if let uploadedImageKey = imageKey {
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: uploadedImageKey, type: "image")
            })
        }
        
        // Clean up any uploaded video (since user is dismissing, it's unused)
        if let videoKey = videoKey {
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: videoKey, type: "video")
            })
        }
        
        // Clean up any uploaded video thumbnail (since user is dismissing, it's unused)
        if let videoThumbnailKey = videoThumbnailKey {
            cleanupTasks.append(Task {
                await deleteUploadedMedia(key: videoThumbnailKey, type: "image")
            })
        }
        
        // Wait for all cleanup tasks to complete
        await withTaskGroup(of: Void.self) { group in
            for task in cleanupTasks {
                group.addTask { await task.value }
            }
        }
    }
    
    /// Deletes a specific uploaded media file from S3
    private func deleteUploadedMedia(key: String, type: String) async {
        do {
            let endpoint = "/api/deleteUploadedMedia?key=\(key)&type=\(type)"
            
            // Check if we have a CSRF token, refresh if needed (same as submitSurfReportWithIOSValidation)
            if AuthManager.shared.csrfToken == nil {
                await withCheckedContinuation { continuation in
                    APIClient.shared.refreshCSRFToken { success in
                        continuation.resume()
                    }
                }
            }
            
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                // Use the same authentication pattern as postRequest
                guard let url = URL(string: "\(APIClient.shared.getBaseURL)\(endpoint)") else {
                    let error = NSError(domain: "APIClient", code: 1, userInfo: [NSLocalizedDescriptionKey: "Invalid URL"])
                    continuation.resume(throwing: error)
                    return
                }
                
                var request = URLRequest(url: url)
                request.httpMethod = "DELETE"
                
                // Add session cookie (same as postRequest)
                if let sessionCookie = AuthManager.shared.getSessionCookie() {
                    for (key, value) in sessionCookie {
                        request.addValue(value, forHTTPHeaderField: key)
                    }
                }
                
                // Add CSRF token for DELETE requests (same as postRequest)
                if let csrfHeader = AuthManager.shared.getCsrfHeader() {
                    for (key, value) in csrfHeader {
                        request.addValue(value, forHTTPHeaderField: key)
                    }
                }
                
                URLSession.shared.dataTask(with: request) { data, response, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    
                    if let httpResponse = response as? HTTPURLResponse {
                        if httpResponse.statusCode == 200 {
                            continuation.resume()
                        } else {
                            let error = NSError(domain: "APIClient", code: httpResponse.statusCode, userInfo: [NSLocalizedDescriptionKey: "HTTP \(httpResponse.statusCode)"])
                            continuation.resume(throwing: error)
                        }
                    } else {
                        let error = NSError(domain: "APIClient", code: 0, userInfo: [NSLocalizedDescriptionKey: "Invalid response"])
                        continuation.resume(throwing: error)
                    }
                }.resume()
            }
        } catch {
            // Silently handle cleanup errors - they're not critical for user experience
        }
    }
}
