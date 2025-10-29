import Foundation
import Combine
import UIKit
import AVFoundation


struct CurrentConditions {
    var waveHeight: String = "N/A"
    var windDirection: String = "N/A"
    var windSpeed: String = "N/A"
    var temperature: String = "N/A"
    var quality: String = "N/A"
}

@MainActor
class LiveSpotViewModel: BaseViewModel {
    @Published var currentConditions = CurrentConditions()
    @Published var recentReports: [SurfReport] = []
    @Published var showReportForm = false
    @Published var showQuickForm = false
    
    func loadSpotData(spotId: String) async {
        logger.log("Loading spot data for: \(spotId)", level: .info, category: .general)
        
        // Placeholder implementation - simulate network delay
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        
        self.currentConditions = CurrentConditions(
            waveHeight: "4-6 ft",
            windDirection: "NW",
            windSpeed: "12 mph",
            temperature: "68°F",
            quality: "Good"
        )
        
        logger.log("Spot data loaded successfully", level: .info, category: .general)
    }
    
    func fetchSurfReports(for spotId: String) {
        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            logger.log("Invalid spotId format: \(spotId)", level: .warning, category: .general)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        logger.log("Fetching surf reports for \(spot)", level: .info, category: .api)
        
        // Clear existing reports before fetching new ones
        self.recentReports = []
        
        executeTask(context: "Fetch surf reports") {
            let responses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchSurfReports(country: country, region: region, spot: spot) { result in
                    continuation.resume(with: result)
                }
            }
            
            let outputDateFormatter = DateFormatter()
            outputDateFormatter.dateFormat = "d MMM, h:mma"
            outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let reports = responses.map { [weak self] response in
                // Parse the timestamp with multiple format support
                let date = self?.parseTimestamp(response.time)
                let formattedTime = date != nil ? outputDateFormatter.string(from: date!) : "Invalid Date"
                
                // Extract just the spot name
                let spotName = response.countryRegionSpot.components(separatedBy: "_").last ?? response.countryRegionSpot
                
                let report = SurfReport(
                    consistency: response.consistency,
                    imageKey: response.imageKey,
                    videoKey: response.videoKey,
                    messiness: response.messiness,
                    quality: response.quality,
                    reporter: response.reporter,
                    surfSize: response.surfSize,
                    time: formattedTime,
                    userEmail: response.userEmail,
                    windAmount: response.windAmount,
                    windDirection: response.windDirection,
                    countryRegionSpot: spotName,
                    dateReported: response.dateReported,
                    mediaType: response.mediaType,
                    iosValidated: response.iosValidated
                )
                
                if let imageKey = response.imageKey, !imageKey.isEmpty {
                    self?.fetchImage(for: imageKey) { imageData in
                        Task { @MainActor [weak self] in
                            report.imageData = imageData?.imageData
                            self?.objectWillChange.send()
                        }
                    }
                }
                
                return report
            }
            
            self.recentReports = reports
            
            // Log image preloading info
            let imageCount = reports.compactMap { $0.imageKey }.filter { !$0.isEmpty }.count
            if imageCount > 0 {
                self.logger.log("Loaded \(reports.count) reports with \(imageCount) images", level: .info, category: .media)
            } else {
                self.logger.log("Loaded \(reports.count) reports", level: .info, category: .api)
            }
        }
    }
    
    private func fetchImage(for key: String, completion: @escaping (SurfReportImageResponse?) -> Void) {
        // First, check the dedicated image cache
        ImageCacheService.shared.getCachedSurfReportImageData(for: key) { [weak self] cachedImageData in
            if let cachedImageData = cachedImageData {
                self?.logger.log("Using cached image for key: \(key)", level: .debug, category: .cache)
                // Create a mock response with the cached image data
                let mockResponse = SurfReportImageResponse(imageData: cachedImageData.base64EncodedString(), contentType: "image/jpeg")
                completion(mockResponse)
                return
            }
            
            // If not cached, fetch from API
            APIClient.shared.getReportImage(key: key) { [weak self] result in
                switch result {
                case .success(let imageData):
                    // Check if imageData is actually present
                    if let imageDataString = imageData.imageData, !imageDataString.isEmpty {
                        // Cache the image for future use
                        if let decodedImageData = Data(base64Encoded: imageDataString),
                           let uiImage = UIImage(data: decodedImageData) {
                            if let pngData = uiImage.pngData() {
                                ImageCacheService.shared.cacheSurfReportImage(pngData, for: key)
                                self?.logger.log("Cached fetched image for key: \(key)", level: .debug, category: .cache)
                            }
                        }
                        completion(imageData)
                    } else {
                        self?.logger.log("Image key \(key) exists but no data returned - likely missing from S3", level: .warning, category: .media)
                        completion(nil)
                    }
                case .failure(let error):
                    self?.logger.log("Failed to fetch image for key \(key): \(error.localizedDescription)", level: .error, category: .media)
                    completion(nil)
                }
            }
        }
    }
    
    // Video handling is now done via presigned URLs in the detail view
    // No need for local video fetching or thumbnail generation
    
    func getSpotName(from spotId: String) -> String {
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else { return "Unknown Spot" }
        return String(components[2])
    }
    
    // Force refresh surf reports by clearing cache and fetching fresh data
    func refreshSurfReports(for spotId: String) {
        logger.log("Refreshing surf reports for spotId: \(spotId)", level: .info, category: .general)
        
        // Clear existing data and error state
        self.recentReports = []
        clearError()
        
        // Fetch fresh data
        fetchSurfReports(for: spotId)
    }
    
    // Parse timestamp with multiple format support
    private func parseTimestamp(_ timestamp: String) -> Date? {
        // Try multiple date formats to handle different timestamp formats
        
        // Format 1: "2025-07-12 19:57:27 +0000 UTC"
        let formatter1 = DateFormatter()
        formatter1.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
        formatter1.locale = Locale(identifier: "en_US_POSIX")
        
        if let date = formatter1.date(from: timestamp) {
            return date
        }
        
        // Format 2: "2025-08-18 22:32:30.819091968 +0000 UTC m=+293.995127367"
        // Extract the main timestamp part before the Go runtime info
        if timestamp.contains(" m=") {
            let components = timestamp.components(separatedBy: " m=")
            if let mainTimestamp = components.first {
                let formatter2 = DateFormatter()
                formatter2.dateFormat = "yyyy-MM-dd HH:mm:ss.SSSSSSSSS ZZZZZ 'UTC'"
                formatter2.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter2.date(from: mainTimestamp) {
                    return date
                }
                
                // Try without microseconds
                let formatter3 = DateFormatter()
                formatter3.dateFormat = "yyyy-MM-dd HH:mm:ss ZZZZZ 'UTC'"
                formatter3.locale = Locale(identifier: "en_US_POSIX")
                
                if let date = formatter3.date(from: mainTimestamp) {
                    return date
                }
            }
        }
        
        // Format 3: Try ISO8601 format
        let isoFormatter = ISO8601DateFormatter()
        if let date = isoFormatter.date(from: timestamp) {
            return date
        }
        
        // Format 4: Unable to parse timestamp
        logger.log("Failed to parse timestamp: \(timestamp)", level: .warning, category: .dataProcessing)
        return nil
    }
}
