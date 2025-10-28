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
    static let shared = SurfReportService()
    
    private let apiClient: APIClientProtocol
    private let imageCacheService: ImageCacheProtocol
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.surfreports.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    init(
        apiClient: APIClientProtocol = APIClient.shared,
        imageCacheService: ImageCacheProtocol = ImageCacheService.shared
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
    ///   - completion: Completion handler with array of SurfReport objects
    func fetchSurfReports(
        country: String,
        region: String,
        completion: @escaping (Result<[SurfReport], Error>) -> Void
    ) {
        // Check cache first
        if let cachedReports = getCachedReports(country: country, region: region) {
            completion(.success(cachedReports))
            return
        }
        
        // First fetch all spots, then get reports for each spot
        apiClient.fetchSpots(country: country, region: region) { [weak self] result in
            switch result {
            case .success(let spots):
                self?.fetchReportsForAllSpots(
                    spots: spots,
                    country: country,
                    region: region,
                    completion: completion
                )
            case .failure(let error):
                completion(.failure(error))
            }
        }
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
        region: String,
        completion: @escaping (Result<[SurfReport], Error>) -> Void
    ) {
        var allReports: [SurfReport] = []
        let group = DispatchGroup()
        
        for spot in spots {
            group.enter()
            apiClient.fetchSurfReports(country: country, region: region, spot: spot.name) { [weak self] result in
                defer { group.leave() }
                
                guard let self = self else { return }
                
                switch result {
                case .success(let responses):
                    let outputDateFormatter = DateFormatter()
                    outputDateFormatter.dateFormat = "d MMM, h:mma"
                    outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    let spotReports = responses.map { response in
                        // Parse the timestamp with multiple format support
                        let date = TimestampParser.parse(response.time)
                        let formattedTime = date != nil ? TimestampParser.formatDate(date!) : "Invalid Date"
                        
                        // Extract just the spot name from countryRegionSpot
                        let spotName = DataFormatter.extractSpotName(from: response.countryRegionSpot)
                        
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
                            // Debug: print the imageKey to see its format
                            print("Debug - ImageKey from API: '\(imageKey)'")
                            // Use the imageKey directly as it should already contain the full path
                            self.fetchImage(for: imageKey) { imageData in
                                Task { @MainActor in
                                    report.imageData = imageData?.imageData
                                    report.objectWillChange.send() // Notify UI of changes
                                }
                            }
                        }
                        
                        return report
                    }
                    
                    allReports.append(contentsOf: spotReports)
                    
                case .failure(let error):
                    print("Failed to fetch surf reports for spot \(spot.name): \(error.localizedDescription)")
                }
            }
        }
        
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }
            
            // Cache the results
            self.cacheReports(allReports, country: country, region: region)
            
            // Preload surf report images for better user experience
            let imageKeys = allReports.compactMap { $0.imageKey }.filter { !$0.isEmpty }
            if !imageKeys.isEmpty {
                print("📱 Preloading \(imageKeys.count) surf report images")
            }
            
            completion(.success(allReports))
        }
    }
    
    private func fetchImage(for key: String, completion: @escaping (SurfReportImageResponse?) -> Void) {
        // First, check the dedicated image cache
        ImageCacheService.shared.getCachedSurfReportImageData(for: key) { cachedImageData in
            if let cachedImageData = cachedImageData {
                print("✅ Using cached surf report image for key: \(key)")
                // Create a mock response with the cached image data
                let mockResponse = SurfReportImageResponse(
                    imageData: cachedImageData.base64EncodedString(),
                    contentType: "image/jpeg"
                )
                completion(mockResponse)
                return
            }
            
            // If not cached, fetch from API
            self.apiClient.getReportImage(key: key) { result in
                switch result {
                case .success(let imageData):
                    // Check if imageData is actually present
                    if let imageDataString = imageData.imageData, !imageDataString.isEmpty {
                        // Cache the image for future use
                        if let decodedImageData = Data(base64Encoded: imageDataString),
                           let uiImage = UIImage(data: decodedImageData) {
                            if let pngData = uiImage.pngData() {
                                ImageCacheService.shared.cacheSurfReportImage(pngData, for: key)
                            }
                        }
                        completion(imageData)
                    } else {
                        print("⚠️ [SURF_REPORT_SERVICE] Image key \(key) exists but no image data returned - likely missing from S3")
                        completion(nil)
                    }
                case .failure(let error):
                    print("❌ [SURF_REPORT_SERVICE] Failed to fetch image for key \(key): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
    }
}

