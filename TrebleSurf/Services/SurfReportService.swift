//
//  SurfReportService.swift
//  TrebleSurf
//
//  Created by Cursor
//

import Foundation
import UIKit
import Combine

// MARK: - Cache Model
struct CachedSurfReports {
    let reports: [SurfReport]
    let timestamp: Date
    let country: String
    let region: String
    
    var isExpired: Bool {
        // Cache expires after 15 minutes
        return Date().timeIntervalSince(timestamp) > 15 * 60
    }
}

// MARK: - Surf Report Service
class SurfReportService: ObservableObject {
    private let apiClient: APIClientProtocol
    private let imageCacheService: ImageCacheProtocol
    private let spotService: SpotServiceProtocol
    private let logger: ErrorLoggerProtocol
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.surfreports.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()

    init(
        apiClient: APIClientProtocol,
        imageCacheService: ImageCacheProtocol,
        spotService: SpotServiceProtocol,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.apiClient = apiClient
        self.imageCacheService = imageCacheService
        self.spotService = spotService
        self.logger = logger ?? ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
        setupCacheCleanup()
    }
    
    // MARK: - Cache Management
    
    private func setupCacheCleanup() {
        // Clean up expired cache entries every 5 minutes
        Timer.publish(every: 5 * 60, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.cleanupExpiredCache()
            }
            .store(in: &cancellables)
    }
    
    private func cleanupExpiredCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let expiredKeys = self.surfReportsCache.keys.filter { key in
                self.surfReportsCache[key]?.isExpired == true
            }
            
            for key in expiredKeys {
                self.surfReportsCache.removeValue(forKey: key)
            }
            
            if !expiredKeys.isEmpty {
                self.logger.log("Cache cleanup: Removed \(expiredKeys.count) expired entries", level: .debug, category: .cache)
            }
        }
    }
    
    private func getCacheKey(country: String, region: String) -> String {
        return "\(country)_\(region)"
    }
    
    private func getCachedReports(country: String, region: String) -> [SurfReport]? {
        let cacheKey = getCacheKey(country: country, region: region)
        guard let cached = surfReportsCache[cacheKey], !cached.isExpired else {
            return nil
        }
        
        logger.log("Cache hit: Using cached surf reports for \(country)/\(region)", level: .debug, category: .cache)
        return cached.reports
    }
    
    private func cacheReports(_ reports: [SurfReport], country: String, region: String) {
        let cacheKey = getCacheKey(country: country, region: region)
        let cached = CachedSurfReports(
            reports: reports,
            timestamp: Date(),
            country: country,
            region: region
        )
        
        cacheQueue.async { [weak self] in
            self?.surfReportsCache[cacheKey] = cached
            self?.logger.log("Cache updated: Stored \(reports.count) surf reports for \(country)/\(region)", level: .debug, category: .cache)
        }
    }
    
    // MARK: - Public Methods
    
    /// Fetch surf reports for all spots in a region
    /// - Parameters:
    ///   - country: Country name
    ///   - region: Region name
    func fetchSurfReports(country: String, region: String) async throws -> [SurfReport] {
        // Check cache first
        if let cachedReports = getCachedReports(country: country, region: region) {
            return cachedReports
        }
        
        // First fetch all spots, then get reports for each spot
        let spots = try await spotService.fetchSpots(country: country, region: region)
        let reports = try await fetchReportsForAllSpots(spots: spots, country: country, region: region)
        
        // Cache the results
        cacheReports(reports, country: country, region: region)
        return reports
    }
    
    /// Clear cache for a specific region
    func clearCache(country: String, region: String) {
        let cacheKey = getCacheKey(country: country, region: region)
        cacheQueue.async { [weak self] in
            self?.surfReportsCache.removeValue(forKey: cacheKey)
            self?.logger.log("Cache cleared for \(country)/\(region)", level: .info, category: .cache)
        }
    }
    
    /// Clear all cached reports
    func clearAllCache() {
        cacheQueue.async { [weak self] in
            self?.surfReportsCache.removeAll()
            self?.logger.log("All surf report cache cleared", level: .info, category: .cache)
        }
    }
    
    // MARK: - API Methods
    
    /// Fetch surf reports for a specific spot (today's reports)
    func fetchReportsForSpot(country: String, region: String, spot: String) async throws -> [SurfReport] {
        // Manually construct endpoint and call request, logic moved from APIClient
        let endpoint = "/api/getTodaySpotReports?country=\(country)&region=\(region)&spot=\(spot)"
        
        logger.log("Fetching today's reports for spot: \(spot)", level: .info, category: .network)
        
        let responses: [SurfReportResponse] = try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
        let reports = responses.map { SurfReport(from: $0) }
        
        // Cache processing could be added here similar to fetchReportsForAllSpots if needed
        
        return reports
    }
    
    func fetchAllSpotReports(country: String, region: String, spot: String, limit: Int = 50) async throws -> [SurfReport] {
        // Manually construct endpoint and call request, logic moved from APIClient
        let endpoint = "/api/getAllSpotReports?country=\(country)&region=\(region)&spot=\(spot)&limit=\(limit)"
        
        logger.log("Fetching all reports for spot: \(spot), limit: \(limit)", level: .info, category: .network)
        
        // Use flexible request method that can handle authentication gracefully
        let responses: [SurfReportResponse] = try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
        let reports = responses.map { response -> SurfReport in
            let report = SurfReport(from: response)
            // Preload images in background
            if let imageKey = response.imageKey, !imageKey.isEmpty {
                logger.log("ImageKey from API: '\(imageKey)'", level: .debug, category: .network)
                Task { @MainActor in
                    if let imageData = await self.fetchImage(for: imageKey) {
                        report.imageData = imageData.imageData
                        report.objectWillChange.send()
                    }
                }
            }
            return report
        }
        
        // Log image preloading info
        let imageKeys = reports.compactMap { $0.imageKey }.filter { !$0.isEmpty }
        if !imageKeys.isEmpty {
            logger.log("Preloading \(imageKeys.count) surf report images", level: .debug, category: .cache)
        }
        
        return reports
    }
    
    func getReportVideo(key: String) async throws -> SurfReportVideoResponse {
        let endpoint = "/api/getReportVideo?key=\(key)"
        return try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
    }
    
    func getVideoViewURL(key: String) async throws -> PresignedVideoViewResponse {
        let endpoint = "/api/generateVideoViewURL?key=\(key)"
        
        logger.log("Getting video view URL for key: \(key)", level: .info, category: .network)
        
        return try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
    }
    
    func getReportImage(key: String) async throws -> SurfReportImageResponse {
        if let response = await fetchImage(for: key) {
             return response
        }
        throw NSError(domain: "SurfReportService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Image not found"])
    }
    
    // MARK: - Private Methods
    
    private func fetchReportsForAllSpots(
        spots: [SpotData],
        country: String,
        region: String
    ) async throws -> [SurfReport] {
        var allReports: [SurfReport] = []
        
        try await withThrowingTaskGroup(of: [SurfReport].self) { group in
            for spot in spots {
                group.addTask { [apiClient] in
                    // Manually construct endpoint and call request, logic moved from APIClient
                    let endpoint = "/api/getTodaySpotReports?country=\(country)&region=\(region)&spot=\(spot.name)"
                    let responses: [SurfReportResponse] = try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
                    return responses.map { response in
                        let report = SurfReport(from: response)
                        if let imageKey = response.imageKey, !imageKey.isEmpty {
                            self.logger.log("ImageKey from API: '\(imageKey)'", level: .debug, category: .network)
                            Task { @MainActor in
                                if let imageData = await self.fetchImage(for: imageKey) {
                                    report.imageData = imageData.imageData
                                    report.objectWillChange.send()
                                }
                            }
                        }
                        return report
                    }
                }
            }
            
            for try await reports in group {
                allReports.append(contentsOf: reports)
            }
        }
        
        // Preload surf report images for better user experience
        let imageKeys = allReports.compactMap { $0.imageKey }.filter { !$0.isEmpty }
        if !imageKeys.isEmpty {
            logger.log("Preloading \(imageKeys.count) surf report images", level: .debug, category: .cache)
        }
        
        return allReports
    }
    
    private func fetchImage(for key: String) async -> SurfReportImageResponse? {
        let cachedImageData = await imageCacheService.getCachedSurfReportImageData(for: key)

        if let cachedImageData = cachedImageData {
            logger.log("Using cached surf report image for key: \(key)", level: .debug, category: .cache)
            return SurfReportImageResponse(
                imageData: cachedImageData.base64EncodedString(),
                contentType: "image/jpeg"
            )
        }
        
        do {
            // Manually construct endpoint and call request, logic moved from APIClient
            let endpoint = "/api/getReportImage?key=\(key)"
            logger.log("Fetching report image for key: \(key)", level: .info, category: .network)
            let imageData: SurfReportImageResponse = try await apiClient.makeFlexibleRequest(to: endpoint, requiresAuth: true)
            
            if let imageDataString = imageData.imageData, !imageDataString.isEmpty {
                if let decodedImageData = Data(base64Encoded: imageDataString),
                   let uiImage = UIImage(data: decodedImageData),
                   let pngData = uiImage.pngData() {
                    imageCacheService.cacheSurfReportImage(pngData, for: key)
                }
                return imageData
            }
            
            logger.log("Image key \(key) exists but no image data returned - likely missing from S3", level: .warning, category: .network)
            return nil
        } catch {
            logger.log("Failed to fetch image for key \(key): \(error.localizedDescription)", level: .error, category: .network)
            return nil
        }
    }
}

