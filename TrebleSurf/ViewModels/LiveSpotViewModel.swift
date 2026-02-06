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
    @Published var matchingConditionReports: [SurfReport] = []
    @Published var isLoadingMatchingReports = false
    @Published var showReportForm = false
    @Published var showQuickForm = false
    
    private let apiClient: APIClientProtocol
    private let surfReportService: SurfReportService
    private let imageCache: ImageCacheProtocol
    
    init(
        apiClient: APIClientProtocol,
        surfReportService: SurfReportService,
        imageCache: ImageCacheProtocol,
        errorHandler: ErrorHandlerProtocol? = nil,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.surfReportService = surfReportService
        self.imageCache = imageCache
        super.init(errorHandler: errorHandler, logger: logger)
    }
    
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
            let reports = try await self.surfReportService.fetchAllSpotReports(country: country, region: region, spot: spot)
            
            let outputDateFormatter = DateFormatter()
            outputDateFormatter.dateFormat = "d MMM, h:mma"
            outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

            
            // The service returns SurfReport array directly, no need to map unless we want to process further
            // But the existing code was mapping responses to SurfReports and preloading images.
            // SurfReportService handles image preloading privately but exposes them on the model?
            // Actually SurfReportService returns [SurfReport] directly.
            // So we can just use them.
            
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
    
    private func fetchImage(for key: String) async -> SurfReportImageResponse? {
        do {
            return try await surfReportService.getReportImage(key: key)
        } catch {
            logger.log("Failed to fetch image for key \(key): \(error.localizedDescription)", level: .error, category: .media)
            return nil
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
    
    func fetchMatchingConditionReports(for spotId: String) {
        // Convert spotId back to country/region/spot format
        let components = spotId.split(separator: "#")
        guard components.count >= 3 else {
            logger.log("Invalid spotId format: \(spotId)", level: .warning, category: .general)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        logger.log("Fetching matching condition reports for \(spot)", level: .info, category: .api)
        
        // Clear existing reports and set loading state
        self.matchingConditionReports = []
        self.isLoadingMatchingReports = true
        
        executeTask(context: "Fetch matching condition reports") {
            // NOTE: fetchSurfReportsWithMatchingConditions is NOT removed from APIClient yet?
            // Checking Protocols.swift (step 184) -> fetchSurfReportsWithMatchingConditions is still there.
            // So this should be fine.
            let responses = try await self.apiClient.fetchSurfReportsWithMatchingConditions(
                country: country,
                region: region,
                spot: spot,
                daysBack: 365,
                maxResults: 20
            )
            
            let outputDateFormatter = DateFormatter()
            outputDateFormatter.dateFormat = "d MMM, h:mma"
            outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

            let reports = responses.map { [weak self] response in
                // Use the convenience initializer that handles optional fields
                let report = SurfReport(from: response)
                
                if let imageKey = response.imageKey, !imageKey.isEmpty {
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        if let imageData = await self.fetchImage(for: imageKey) {
                            report.imageData = imageData.imageData
                            self.objectWillChange.send()
                        }
                    }
                }
                
                return report
            }
            
            self.matchingConditionReports = reports
            self.isLoadingMatchingReports = false
            
            // Log matching reports info
            let imageCount = reports.compactMap { $0.imageKey }.filter { !$0.isEmpty }.count
            if imageCount > 0 {
                self.logger.log("Loaded \(reports.count) matching reports with \(imageCount) images", level: .info, category: .media)
            } else {
                self.logger.log("Loaded \(reports.count) matching reports", level: .info, category: .api)
            }
        }
    }
    
    // Force refresh matching condition reports
    func refreshMatchingConditionReports(for spotId: String) {
        logger.log("Refreshing matching condition reports for spotId: \(spotId)", level: .info, category: .general)
        
        // Clear existing data and error state
        self.matchingConditionReports = []
        clearError()
        
        // Fetch fresh data
        fetchMatchingConditionReports(for: spotId)
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
