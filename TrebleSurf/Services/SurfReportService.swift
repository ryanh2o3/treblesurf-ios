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
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.surfreports.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    init(
        apiClient: APIClientProtocol,
        imageCacheService: ImageCacheProtocol
    ) {
        self.apiClient = apiClient
        self.imageCacheService = imageCacheService
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
                print("Cache cleanup: Removed \(expiredKeys.count) expired entries")
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
        
        print("Cache hit: Using cached surf reports for \(country)/\(region)")
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
            print("Cache updated: Stored \(reports.count) surf reports for \(country)/\(region)")
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
        let spots = try await apiClient.fetchSpots(country: country, region: region)
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
            print("Cache cleared for \(country)/\(region)")
        }
    }
    
    /// Clear all cached reports
    func clearAllCache() {
        cacheQueue.async { [weak self] in
            self?.surfReportsCache.removeAll()
            print("All surf report cache cleared")
        }
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
                    let responses = try await apiClient.fetchSurfReports(country: country, region: region, spot: spot.name)
                    return responses.map { response in
                        let report = SurfReport(from: response)
                        if let imageKey = response.imageKey, !imageKey.isEmpty {
                            print("Debug - ImageKey from API: '\(imageKey)'")
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
            print("📱 Preloading \(imageKeys.count) surf report images")
        }
        
        return allReports
    }
    
    private func fetchImage(for key: String) async -> SurfReportImageResponse? {
        let cachedImageData = await withCheckedContinuation { continuation in
            imageCacheService.getCachedSurfReportImageData(for: key) { data in
                continuation.resume(returning: data)
            }
        }
        
        if let cachedImageData = cachedImageData {
            print("✅ Using cached surf report image for key: \(key)")
            return SurfReportImageResponse(
                imageData: cachedImageData.base64EncodedString(),
                contentType: "image/jpeg"
            )
        }
        
        do {
            let imageData = try await apiClient.getReportImage(key: key)
            if let imageDataString = imageData.imageData, !imageDataString.isEmpty {
                if let decodedImageData = Data(base64Encoded: imageDataString),
                   let uiImage = UIImage(data: decodedImageData),
                   let pngData = uiImage.pngData() {
                    imageCacheService.cacheSurfReportImage(pngData, for: key)
                }
                return imageData
            }
            
            print("⚠️ [SURF_REPORT_SERVICE] Image key \(key) exists but no image data returned - likely missing from S3")
            return nil
        } catch {
            print("❌ [SURF_REPORT_SERVICE] Failed to fetch image for key \(key): \(error.localizedDescription)")
            return nil
        }
    }
}

