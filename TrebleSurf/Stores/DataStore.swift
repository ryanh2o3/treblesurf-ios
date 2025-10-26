//
//  DataStore.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 11/05/2025.
//
import Foundation
import SwiftUI

@MainActor
class DataStore: ObservableObject, DataStoreProtocol {
    static let shared = DataStore()
    
    private let config: AppConfigurationProtocol
    private let apiClient: APIClientProtocol
    
    init(
        config: AppConfigurationProtocol = AppConfiguration.shared,
        apiClient: APIClientProtocol = APIClient.shared
    ) {
        self.config = config
        self.apiClient = apiClient
    }

    @Published var currentConditions = ConditionData(from: [:])
    @Published var currentConditionsTimestamp: String = ""
    // Cache for storing multiple spot conditions with timestamps
    private var spotConditionsCache: [String: (conditions: ConditionData, forecastTimestamp: String, timestamp: Date)] = [:]
    
    // Use configuration for cache expiration
    private var cacheExpirationInterval: TimeInterval {
        config.cacheExpirationInterval
    }
    
    private var spotCacheExpirationInterval: TimeInterval {
        config.spotCacheExpirationInterval
    }
    
    // Computed property for relative time display
    var relativeTimeDisplay: String {
        guard !currentConditionsTimestamp.isEmpty else { return "Unknown" }
        
        // Convert Unix timestamp to Date
        if let timestamp = Double(currentConditionsTimestamp) {
            let date = Date(timeIntervalSince1970: timestamp)
            let now = Date()
            let timeInterval = now.timeIntervalSince(date)
            
            let minutes = Int(timeInterval / 60)
            let hours = Int(timeInterval / 3600)
            let days = Int(timeInterval / 86400)
            print("current timestamp", currentConditionsTimestamp)
            
            if days > 0 {
                return "\(days) day\(days == 1 ? "" : "s") ago"
            } else if hours > 0 {
                return "\(hours) hour\(hours == 1 ? "" : "s") ago"
            } else if minutes > 0 {
                return "\(minutes) min\(minutes == 1 ? "" : "s") ago"
            } else {
                return "Just now"
            }
        }
        
        return "Unknown"
    }
    
    @Published var regionSpots: [SpotData] = []
    private var regionSpotsCache: [String: (spots: [SpotData], timestamp: Date)] = [:]
    
    // Using only the flattened format
        @Published var currentForecastEntries: [ForecastEntry] = []
        private var spotForecastCache: [String: (forecast: [ForecastEntry], timestamp: Date)] = [:]
    
    // Current selected spot ID
    @Published var currentSpotId: String = ""
    
    // Fetch conditions for a spot
    func fetchConditions(for spotId: String, completion: @escaping (Bool) -> Void = {_ in}) {
        // Check if we have cached data that's still valid
        if let cached = spotConditionsCache[spotId],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            
            // Use cached data - already on main thread since we're @MainActor
            currentSpotId = spotId
            currentConditions = cached.conditions
            currentConditionsTimestamp = cached.forecastTimestamp
            completion(true)
            return
        }

        // Split the spotId into components
        let components = spotId.split(separator: "#")
        guard components.count == 3 else {
            print("Invalid spotId format")
            completion(false)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        // Make API call
        apiClient.fetchCurrentConditions(country: country, region: region, spot: spot) { [weak self] (result: Result<[CurrentConditionsResponse], Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(let responses):
                if let firstResponse = responses.first {
                    // Update on main actor (handled by @MainActor annotation)
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Update current conditions
                        self.currentConditions = firstResponse.data
                        self.currentConditionsTimestamp = firstResponse.generated_at
                        
                        // Update current spot ID
                        self.currentSpotId = spotId
                        
                        // Cache the data with current timestamp
                        self.spotConditionsCache[spotId] = (firstResponse.data, firstResponse.generated_at, Date())
                        
                        completion(true)
                    }
                }
                
            case .failure(let error):
                print("Error fetching conditions: \(error)")
                completion(false)
            }
        }
    }
    
    func fetchForecast(for spotId: String, completion: @escaping (Bool) -> Void = {_ in}) {
            // Check if we have cached data that's still valid
            if let cached = spotForecastCache[spotId],
               Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
                
                // Use cached data - already on main thread
                currentForecastEntries = cached.forecast
                completion(true)
                return
            }

            // Split the spotId into components
            let components = spotId.split(separator: "#")
            guard components.count == 3 else {
                print("Invalid spotId format")
                completion(false)
                return
            }
            
            let country = String(components[0])
            let region = String(components[1])
            let spot = String(components[2])
            
            // Make API call and convert response to ForecastEntry objects directly
            apiClient.fetchForecast(country: country, region: region, spot: spot) { [weak self] (result: Result<[ForecastResponse], Error>) in
                guard let self = self else { return }
                
                switch result {
                case .success(let responses):
                    // Convert to ForecastEntry objects
                    let entries = responses.toForecastEntries()
                    
                    // Update on main actor
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Update current forecast with flattened data
                        self.currentForecastEntries = entries
                        
                        // Cache the flattened data with current timestamp
                        self.spotForecastCache[spotId] = (entries, Date())
                        
                        completion(true)
                    }
                    
                case .failure(let error):
                    print("Error fetching forecast: \(error)")
                    completion(false)
                }
            }
        }
    
    func fetchRegionSpots(region: String, completion: @escaping (Result<[SpotData], Error>) -> Void) {
        // Check if we have cached data that's still valid
        if let cached = regionSpotsCache[region],
           Date().timeIntervalSince(cached.timestamp) < spotCacheExpirationInterval {
            
            // Use cached data - already on main thread
            completion(.success(cached.spots))
            return
        }

        print("Fetching spots for region: \(region)")
        
        // For now we only handle Donegal, but this could be expanded
        apiClient.fetchDonegalSpots { [weak self] result in
            guard let self = self else { return }
            print("result \(result)")
            switch result {
            case .success(let spots):
                print("Successfully fetched \(spots.count) spots for region: \(region)")
                
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Cache the data with current timestamp (on main thread)
                    self.regionSpotsCache[region] = (spots, Date())
                    // Update the published property
                    self.regionSpots = spots
                    completion(.success(spots))
                    
                    // Preload spot images for better user experience
                    self.preloadSpotImages(for: region)
                }
                
            case .failure(let error):
                print("Error fetching spots for region \(region): \(error)")
                print("Error details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func fetchSpotImage(for spotId: String, completion: @escaping (Image?) -> Void = {_ in}) {
        print("Fetching image for spotId: \(spotId)")
        
        // First, check the dedicated image cache
        ImageCacheService.shared.getCachedSpotImage(for: spotId) { cachedImage in
            if let cachedImage = cachedImage {
                print("✅ Using cached spot image for spotId: \(spotId)")
                completion(cachedImage)
                return
            }
            
            // Check if we have cached data with image already in regionSpotsCache
            for (_, cachedData) in self.regionSpotsCache {
                if let spotIndex = cachedData.spots.firstIndex(where: { $0.id == spotId }),
                   let imageData = cachedData.spots[spotIndex].imageString,
                   !imageData.isEmpty,
                   Date().timeIntervalSince(cachedData.timestamp) < self.spotCacheExpirationInterval {
                    print("Using cached image data from regionSpotsCache for spotId: \(spotId)")
                    
                        // Convert base64 to UIImage if we have it cached
                        if let image = UIImage(data: Data(base64Encoded: imageData) ?? Data()) {
                            let swiftUIImage = Image(uiImage: image)
                            
                            // Cache this image in the dedicated image cache for future use
                            if let imageData = image.pngData() {
                                ImageCacheService.shared.cacheSpotImage(imageData, for: spotId)
                            }
                            
                            Task { @MainActor in
                                completion(swiftUIImage)
                            }
                            return
                        }
                }
            }
            
            // Split the spotId into components
            let components = spotId.split(separator: "#")
            guard components.count == 3 else {
                print("Invalid spotId format")
                completion(nil)
                return
            }
            
            let country = String(components[0])
            let region = String(components[1])
            let spot = String(components[2])
            
            // Call locationInfo API route
            self.apiClient.fetchLocationInfo(country: country, region: region, spot: spot) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let spotData):
                    Task { @MainActor [weak self] in
                        guard let self = self else { return }
                        // Update cache with the new image data
                        for (regionKey, cachedData) in self.regionSpotsCache {
                            var updatedSpots = cachedData.spots
                            if let index = updatedSpots.firstIndex(where: { $0.id == spotId }) {
                                // Create a mutable copy of the original spot
                                var updatedSpot = updatedSpots[index]
                                // Update the image property
                                updatedSpot.imageString = spotData.image
                                // Replace the spot in the array
                                updatedSpots[index] = updatedSpot
                                // Update the cache
                                self.regionSpotsCache[regionKey] = (updatedSpots, Date())
                            }
                        }
                        
                        // Convert base64 to UIImage
                        if let imageData = spotData.imageString,
                           let image = UIImage(data: Data(base64Encoded: imageData) ?? Data()) {
                            let swiftUIImage = Image(uiImage: image)
                            
                            // Cache this image in the dedicated image cache for future use
                            if let pngData = image.pngData() {
                                ImageCacheService.shared.cacheSpotImage(pngData, for: spotId)
                            }
                            
                            Task { @MainActor in
                                completion(swiftUIImage)
                            }
                        } else {
                            completion(nil)
                        }
                        
                        // Preload other spot images for this region to improve user experience
                        let components = spotId.split(separator: "#")
                        if components.count == 3 {
                            let region = String(components[1])
                            self.preloadSpotImages(for: region)
                        }
                        
                        // Preload surf report images for this spot to improve user experience
                        // This would require access to surf report data, which is handled in the ViewModels
                        
                        // Note: Surf report image preloading is handled in the ViewModels
                        // when they fetch surf reports, as they have access to the image keys
                        }
                    
                case .failure(let error):
                    print("Error fetching spot image: \(error)")
                    completion(nil)
                }
            }
        }
    }
    
    // Clear expired cache entries
    func cleanCache() {
        let now = Date()
        spotConditionsCache = spotConditionsCache.filter {
            now.timeIntervalSince($0.value.timestamp) < cacheExpirationInterval
        }
        
        spotForecastCache = spotForecastCache.filter {
                    now.timeIntervalSince($0.value.timestamp) < cacheExpirationInterval
                }
    }
    
    // Clear specific caches for refresh
    func clearSpotCache(for spotId: String? = nil) {
        if let spotId = spotId {
            // Clear specific spot cache
            spotConditionsCache.removeValue(forKey: spotId)
            spotForecastCache.removeValue(forKey: spotId)
        } else {
            // Clear all spot caches
            spotConditionsCache.removeAll()
            spotForecastCache.removeAll()
        }
    }
    
    // Clear image cache for a specific spot or all images
    func clearImageCache(for spotId: String? = nil) {
        if let spotId = spotId {
            // Clear specific spot image cache
            ImageCacheService.shared.removeCachedSpotImage(for: spotId)
        } else {
            // Clear all image caches
            ImageCacheService.shared.clearAllCache()
        }
    }
    
    // Preload spot images for a region to improve user experience
    func preloadSpotImages(for region: String) {
        // Get all spots for the region and preload their images
        if let cachedData = regionSpotsCache[region] {
            let spotIds = cachedData.spots.map { $0.id }
            let imageKeys = spotIds.map { "spot_\($0)" }
            ImageCacheService.shared.preloadImages(for: imageKeys)
        }
    }
    
    // Get image cache statistics for debugging
    func getImageCacheStats() -> (totalImages: Int, memoryUsage: String, diskUsage: String) {
        return ImageCacheService.shared.getCacheStats()
    }
    
    // Get detailed image cache statistics by type
    func getDetailedImageCacheStats() -> (spotImages: Int, reportImages: Int, totalImages: Int, memoryUsage: String, diskUsage: String) {
        return ImageCacheService.shared.getDetailedCacheStats()
    }
    
    // Export image cache information for debugging
    func exportImageCacheInfo() -> String {
        return ImageCacheService.shared.exportCacheInfo()
    }
    
    // Test the image cache system
    func testImageCache() {
        print("🧪 Testing image cache system...")
        
        // Get cache statistics
        let stats = getDetailedImageCacheStats()
        print("📊 Cache stats: \(stats.spotImages) spot images, \(stats.reportImages) report images, \(stats.totalImages) total")
        print("💾 Memory usage: \(stats.memoryUsage), Disk usage: \(stats.diskUsage)")
        
        // Export detailed cache info
        let cacheInfo = exportImageCacheInfo()
        print("📋 Cache info:\n\(cacheInfo)")
        
        print("✅ Image cache test completed")
    }
    
    // Clean up any corrupted cache files
    func cleanupImageCache() {
        ImageCacheService.shared.cleanExpiredCache()
        print("🧹 Image cache cleanup completed")
    }
    
    // Refresh image cache for a specific spot
    func refreshSpotImage(for spotId: String, completion: @escaping (Image?) -> Void = {_ in}) {
        // Clear the cached image first
        clearImageCache(for: spotId)
        
        // Fetch the image again
        fetchSpotImage(for: spotId, completion: completion)
    }
    
    // Refresh all image caches
    func refreshAllImageCaches() {
        clearImageCache()
        print("🔄 All image caches cleared and ready for refresh")
    }
    
    // Clear region spots cache for refresh
    func clearRegionSpotsCache(for region: String? = nil) {
        if let region = region {
            regionSpotsCache.removeValue(forKey: region)
        } else {
            regionSpotsCache.removeAll()
        }
    }
    
    // Refresh all data (clear all caches)
    func refreshAllData() {
        clearSpotCache()
        clearRegionSpotsCache()
        clearImageCache() // Also clear all image caches
        currentConditions = ConditionData(from: [:])
        currentConditionsTimestamp = ""
        currentForecastEntries = []
        print("🔄 All data and image caches cleared")
    }
    
    // Refresh data for a specific spot
    func refreshSpotData(for spotId: String) {
        clearSpotCache(for: spotId)
        clearImageCache(for: spotId) // Also clear the spot's image cache
        // Reset current conditions if this is the currently selected spot
        if currentSpotId == spotId {
            currentConditions = ConditionData(from: [:])
            currentConditionsTimestamp = ""
        }
        print("🔄 Cleared spot data and image cache for \(spotId)")
    }
    
    // Refresh all data for a specific region
    func refreshRegionData(for region: String) {
        clearRegionSpotsCache(for: region)
        
        // Clear associated spot image caches
        if let cachedData = regionSpotsCache[region] {
            for spot in cachedData.spots {
                ImageCacheService.shared.removeCachedSpotImage(for: spot.id)
            }
        }
        
        print("🔄 Cleared region spots cache and associated image caches for \(region)")
    }
    
    /// Reset the store to its initial state - clears all data and caches
    func resetToInitialState() {
        // Reset all published properties to initial values (already on main thread)
        currentConditions = ConditionData(from: [:])
        currentConditionsTimestamp = ""
        currentForecastEntries = []
        currentSpotId = ""
        regionSpots = []
        
        // Clear all caches
        spotConditionsCache.removeAll()
        spotForecastCache.removeAll()
        regionSpotsCache.removeAll()
        clearImageCache() // Also clear all image caches
        
        print("DataStore reset to initial state including image caches")
    }
}
