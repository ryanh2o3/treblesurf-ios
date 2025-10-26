//
//  ImageCacheService.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 05/05/2025.
//

import Foundation
import UIKit
import SwiftUI

// MARK: - Cached Image Data
struct CachedImageData: Codable {
    let imageData: Data
    let timestamp: Date
    let key: String
    
    var isExpired: Bool {
        // Cache images for 30 days since they never change
        let cacheExpirationInterval: TimeInterval = 30 * 24 * 60 * 60
        return Date().timeIntervalSince(timestamp) > cacheExpirationInterval
    }
}

// MARK: - Image Cache Service
class ImageCacheService: ObservableObject, ImageCacheProtocol {
    static let shared = ImageCacheService()
    
    // MARK: - Properties
    private var imageCache: [String: CachedImageData] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.imagecache", qos: .utility)
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    
    // MARK: - Initialization
    private init() {
        // Create cache directory in app's documents folder
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        cacheDirectory = documentsPath.appendingPathComponent("ImageCache")
        
        // Create cache directory if it doesn't exist
        try? fileManager.createDirectory(at: cacheDirectory, withIntermediateDirectories: true)
        
        // Load existing cache from disk
        loadCacheFromDisk()
        
        // Start periodic cache cleanup
        startCacheCleanup()
    }
    
    // MARK: - Public Methods
    
    /// Get a cached image for a given key
    /// - Parameters:
    ///   - key: Unique identifier for the image
    ///   - completion: Completion handler with the cached image or nil if not found/expired
    func getCachedImage(for key: String, completion: @escaping (Image?) -> Void) {
        cacheQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let cachedData = self.imageCache[key], !cachedData.isExpired {
                // Image found in memory cache
                if let uiImage = UIImage(data: cachedData.imageData) {
                    let swiftUIImage = Image(uiImage: uiImage)
                    DispatchQueue.main.async {
                        completion(swiftUIImage)
                    }
                    return
                }
            }
            
            // Try to load from disk cache
            if let diskCachedData = self.loadImageFromDisk(for: key) {
                // Update memory cache
                self.imageCache[key] = diskCachedData
                
                if let uiImage = UIImage(data: diskCachedData.imageData) {
                    let swiftUIImage = Image(uiImage: uiImage)
                    DispatchQueue.main.async {
                        completion(swiftUIImage)
                    }
                    return
                }
            }
            
            // No cached image found
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    /// Get cached image data for a given key (returns raw Data instead of SwiftUI Image)
    /// - Parameters:
    ///   - key: Unique identifier for the image
    ///   - completion: Completion handler with the cached image data or nil if not found/expired
    func getCachedImageData(for key: String, completion: @escaping (Data?) -> Void) {
        cacheQueue.async { [weak self] in
            guard let self = self else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            if let cachedData = self.imageCache[key], !cachedData.isExpired {
                // Image found in memory cache
                DispatchQueue.main.async {
                    completion(cachedData.imageData)
                }
                return
            }
            
            // Try to load from disk cache
            if let diskCachedData = self.loadImageFromDisk(for: key) {
                // Update memory cache
                self.imageCache[key] = diskCachedData
                
                DispatchQueue.main.async {
                    completion(diskCachedData.imageData)
                }
                return
            }
            
            // No cached image data found
            DispatchQueue.main.async { completion(nil) }
        }
    }
    
    /// Cache an image with a given key
    /// - Parameters:
    ///   - imageData: The image data to cache
    ///   - key: Unique identifier for the image
    func cacheImage(_ imageData: Data, for key: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let cachedData = CachedImageData(
                imageData: imageData,
                timestamp: Date(),
                key: key
            )
            
            // Update memory cache
            self.imageCache[key] = cachedData
            
            // Save to disk
            self.saveImageToDisk(cachedData)
            
            print("✅ Cached image for key: \(key)")
        }
    }
    
    /// Check if an image is cached and valid
    /// - Parameter key: Unique identifier for the image
    /// - Returns: True if the image is cached and not expired
    func hasCachedImage(for key: String) -> Bool {
        if let cachedData = imageCache[key], !cachedData.isExpired {
            return true
        }
        
        // Check disk cache
        return loadImageFromDisk(for: key) != nil
    }
    
    /// Clear all cached images
    func clearAllCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Clear memory cache
            self.imageCache.removeAll()
            
            // Clear disk cache
            try? self.fileManager.removeItem(at: self.cacheDirectory)
            try? self.fileManager.createDirectory(at: self.cacheDirectory, withIntermediateDirectories: true)
            
            print("🗑️ Cleared all image cache")
        }
    }
    
    /// Remove a specific cached image
    /// - Parameter key: The key of the image to remove
    func removeCachedImage(for key: String) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            // Remove from memory cache
            self.imageCache.removeValue(forKey: key)
            
            // Remove from disk cache
            self.removeImageFromDisk(for: key)
            
            print("🗑️ Removed cached image for key: \(key)")
        }
    }
    
    /// Clear expired cache entries
    func cleanExpiredCache() {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            let expiredKeys = self.imageCache.keys.filter { key in
                self.imageCache[key]?.isExpired == true
            }
            
            for key in expiredKeys {
                self.imageCache.removeValue(forKey: key)
                self.removeImageFromDisk(for: key)
            }
            
            if !expiredKeys.isEmpty {
                print("🧹 Cleaned \(expiredKeys.count) expired image cache entries")
            }
        }
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> (totalImages: Int, memoryUsage: String, diskUsage: String) {
        let totalImages = imageCache.count
        
        // Calculate memory usage
        let memoryUsage = imageCache.values.reduce(0) { total, cachedData in
            total + cachedData.imageData.count
        }
        let memoryUsageMB = Double(memoryUsage) / (1024 * 1024)
        
        // Calculate disk usage
        var diskUsage: UInt64 = 0
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in fileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    diskUsage += UInt64(fileSize)
                }
            }
        } catch {
            print("❌ Failed to calculate disk usage: \(error)")
        }
        let diskUsageMB = Double(diskUsage) / (1024 * 1024)
        
        return (
            totalImages: totalImages,
            memoryUsage: String(format: "%.2f MB", memoryUsageMB),
            diskUsage: String(format: "%.2f MB", diskUsageMB)
        )
    }
    
    /// Get detailed cache statistics by type
    func getDetailedCacheStats() -> (spotImages: Int, reportImages: Int, totalImages: Int, memoryUsage: String, diskUsage: String) {
        let totalImages = imageCache.count
        
        // Count by type
        let spotImages = imageCache.keys.filter { $0.hasPrefix("spot_") }.count
        let reportImages = imageCache.keys.filter { $0.hasPrefix("report_") }.count
        
        // Calculate memory usage
        let memoryUsage = imageCache.values.reduce(0) { total, cachedData in
            total + cachedData.imageData.count
        }
        let memoryUsageMB = Double(memoryUsage) / (1024 * 1024)
        
        // Calculate disk usage
        var diskUsage: UInt64 = 0
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: [.fileSizeKey])
            for fileURL in fileURLs {
                if let resourceValues = try? fileURL.resourceValues(forKeys: [.fileSizeKey]),
                   let fileSize = resourceValues.fileSize {
                    diskUsage += UInt64(fileSize)
                }
            }
        } catch {
            print("❌ Failed to calculate disk usage: \(error)")
        }
        let diskUsageMB = Double(diskUsage) / (1024 * 1024)
        
        return (
            spotImages: spotImages,
            reportImages: reportImages,
            totalImages: totalImages,
            memoryUsage: String(format: "%.2f MB", memoryUsageMB),
            diskUsage: String(format: "%.2f MB", diskUsageMB)
        )
    }
    
    /// Export cache information for debugging
    func exportCacheInfo() -> String {
        let stats = getDetailedCacheStats()
        let now = Date()
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .medium
        
        var info = """
        Image Cache Information
        =======================
        Generated: \(formatter.string(from: now))
        
        Statistics:
        - Total Images: \(stats.totalImages)
        - Spot Images: \(stats.spotImages)
        - Report Images: \(stats.reportImages)
        - Memory Usage: \(stats.memoryUsage)
        - Disk Usage: \(stats.diskUsage)
        
        Cached Keys:
        """
        
        for key in imageCache.keys.sorted() {
            if let cachedData = imageCache[key] {
                let age = now.timeIntervalSince(cachedData.timestamp)
                let ageString = formatTimeInterval(age)
                let sizeKB = Double(cachedData.imageData.count) / 1024
                info += "\n- \(key): \(ageString) old, \(String(format: "%.1f KB", sizeKB))"
            }
        }
        
        return info
    }
    
    /// Format time interval in human-readable format
    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let days = Int(interval / 86400)
        let hours = Int((interval.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((interval.truncatingRemainder(dividingBy: 3600)) / 60)
        
        if days > 0 {
            return "\(days)d \(hours)h"
        } else if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else if minutes > 0 {
            return "\(minutes)m"
        } else {
            return "Just now"
        }
    }
    
    /// Preload images for better user experience
    /// - Parameter keys: Array of image keys to preload
    func preloadImages(for keys: [String]) {
        cacheQueue.async { [weak self] in
            guard let self = self else { return }
            
            for key in keys {
                // Check if already cached
                if self.hasCachedImage(for: key) {
                    continue
                }
                
                // For now, we can't preload without the actual image data
                // This method could be extended to work with a preloader service
                print("📱 Preload requested for key: \(key) (already cached or not available)")
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCacheFromDisk() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "cache" {
                    let sanitizedKey = fileURL.deletingPathExtension().lastPathComponent
                    
                    // Try to load the cached data using the sanitized filename
                    do {
                        let data = try Data(contentsOf: fileURL)
                        let decoder = JSONDecoder()
                        let cachedData = try decoder.decode(CachedImageData.self, from: data)
                        
                        // Check if expired
                        if !cachedData.isExpired {
                            // Use the original key from the cached data, not the sanitized filename
                            imageCache[cachedData.key] = cachedData
                        } else {
                            // Remove expired file
                            try? fileManager.removeItem(at: fileURL)
                        }
                    } catch {
                        // If we can't decode, remove the corrupted file
                        try? fileManager.removeItem(at: fileURL)
                    }
                }
            }
            
            print("📱 Loaded \(imageCache.count) cached images from disk")
        } catch {
            print("❌ Failed to load cache from disk: \(error)")
        }
    }
    
    private func saveImageToDisk(_ cachedData: CachedImageData) {
        let sanitizedKey = sanitizeFilename(cachedData.key)
        let fileURL = cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
        
        do {
            let encoder = JSONEncoder()
            let data = try encoder.encode(cachedData)
            try data.write(to: fileURL)
        } catch {
            print("❌ Failed to save image to disk: \(error)")
        }
    }
    
    private func loadImageFromDisk(for key: String) -> CachedImageData? {
        let sanitizedKey = sanitizeFilename(key)
        let fileURL = cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
        
        do {
            let data = try Data(contentsOf: fileURL)
            let decoder = JSONDecoder()
            let cachedData = try decoder.decode(CachedImageData.self, from: data)
            
            // Check if expired
            if cachedData.isExpired {
                removeImageFromDisk(for: key)
                return nil
            }
            
            return cachedData
        } catch {
            return nil
        }
    }
    
    private func removeImageFromDisk(for key: String) {
        let sanitizedKey = sanitizeFilename(key)
        let fileURL = cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
        try? fileManager.removeItem(at: fileURL)
    }
    
    /// Sanitize filename by replacing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        // Replace invalid characters with underscores
        let invalidCharacters = CharacterSet(charactersIn: ":/\\?%*|\"<>")
        return filename.components(separatedBy: invalidCharacters).joined(separator: "_")
    }
    
    private func startCacheCleanup() {
        // Clean up expired cache every hour
        Timer.scheduledTimer(withTimeInterval: 60 * 60, repeats: true) { [weak self] _ in
            self?.cleanExpiredCache()
        }
        
        // Listen for memory pressure notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryPressure),
            name: UIApplication.didReceiveMemoryWarningNotification,
            object: nil
        )
        
        // Listen for app lifecycle events
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppDidEnterBackground),
            name: UIApplication.didEnterBackgroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
        
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppWillTerminate),
            name: UIApplication.willTerminateNotification,
            object: nil
        )
    }
    
    @objc private func handleAppWillTerminate() {
        print("📱 App terminating, ensuring cache is saved to disk")
        // Force save all cached data to disk
        for (key, cachedData) in imageCache {
            saveImageToDisk(cachedData)
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        print("📱 App entering background, saving cache to disk")
        // The cache is already saved to disk, but we can perform additional cleanup
        cleanExpiredCache()
    }
    
    @objc private func handleAppWillEnterForeground() {
        print("📱 App entering foreground, loading cache from disk")
        // Reload cache from disk in case it was cleared by the system
        loadCacheFromDisk()
    }
    
    deinit {
        // Remove observers when the service is deallocated
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMemoryPressure() {
        print("⚠️ Memory pressure detected, clearing memory cache")
        
        // Keep only the most recently accessed images in memory
        let sortedKeys = imageCache.keys.sorted { key1, key2 in
            guard let data1 = imageCache[key1], let data2 = imageCache[key2] else { return false }
            return data1.timestamp > data2.timestamp
        }
        
        // Keep only the 10 most recent images in memory
        let keysToKeep = Array(sortedKeys.prefix(10))
        let keysToRemove = imageCache.keys.filter { !keysToKeep.contains($0) }
        
        for key in keysToRemove {
            imageCache.removeValue(forKey: key)
        }
        
        if !keysToRemove.isEmpty {
            print("🧹 Removed \(keysToRemove.count) images from memory cache due to memory pressure")
        }
    }
}

// MARK: - Convenience Extensions

extension ImageCacheService {
    /// Get a cached image for a spot ID
    /// - Parameters:
    ///   - spotId: The spot identifier
    ///   - completion: Completion handler with the cached image or nil if not found
    func getCachedSpotImage(for spotId: String, completion: @escaping (Image?) -> Void) {
        getCachedImage(for: "spot_\(spotId)", completion: completion)
    }
    
    /// Get cached image data for a spot ID (returns raw Data instead of SwiftUI Image)
    /// - Parameters:
    ///   - spotId: The spot identifier
    ///   - completion: Completion handler with the cached image data or nil if not found
    func getCachedSpotImageData(for spotId: String, completion: @escaping (Data?) -> Void) {
        getCachedImageData(for: "spot_\(spotId)", completion: completion)
    }
    
    /// Cache a spot image
    /// - Parameters:
    ///   - imageData: The image data to cache
    ///   - spotId: The spot identifier
    func cacheSpotImage(_ imageData: Data, for spotId: String) {
        cacheImage(imageData, for: "spot_\(spotId)")
    }
    
    /// Get a cached image for a surf report
    /// - Parameters:
    ///   - imageKey: The surf report image key
    ///   - completion: Completion handler with the cached image or nil if not found
    func getCachedSurfReportImage(for imageKey: String, completion: @escaping (Image?) -> Void) {
        getCachedImage(for: "report_\(imageKey)", completion: completion)
    }
    
    /// Get cached image data for a surf report (returns raw Data instead of SwiftUI Image)
    /// - Parameters:
    ///   - imageKey: The surf report image key
    ///   - completion: Completion handler with the cached image data or nil if not found
    func getCachedSurfReportImageData(for imageKey: String, completion: @escaping (Data?) -> Void) {
        getCachedImageData(for: "report_\(imageKey)", completion: completion)
    }
    
    /// Cache a surf report image
    /// - Parameters:
    ///   - imageData: The image data to cache
    ///   - imageKey: The surf report image key
    func cacheSurfReportImage(_ imageData: Data, for imageKey: String) {
        cacheImage(imageData, for: "report_\(imageKey)")
    }
    
    /// Remove a cached spot image
    /// - Parameter spotId: The spot identifier
    func removeCachedSpotImage(for spotId: String) {
        removeCachedImage(for: "spot_\(spotId)")
    }
    
    /// Remove a cached surf report image
    /// - Parameter imageKey: The surf report image key
    func removeCachedSurfReportImage(for imageKey: String) {
        removeCachedImage(for: "report_\(imageKey)")
    }
}

// MARK: - SwiftUI Image Extensions

// Note: The asUIImage() extension was removed to avoid SwiftUI rendering issues
// Instead, use getCachedImageData() methods that return raw Data
