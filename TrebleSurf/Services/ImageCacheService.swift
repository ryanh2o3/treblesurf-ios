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
class ImageCacheService: ObservableObject, ImageCacheProtocol, @unchecked Sendable {
    // MARK: - Properties
    private var imageCache: [String: CachedImageData] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.imagecache", qos: .utility)
    private let fileManager = FileManager.default
    private let cacheDirectory: URL
    private let logger: ErrorLoggerProtocol

    // MARK: - Initialization
    init(logger: ErrorLoggerProtocol? = nil) {
        self.logger = logger ?? ErrorLogger(minimumLogLevel: .debug, enableConsoleOutput: true, enableOSLog: true)
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
    /// - Parameter key: Unique identifier for the image
    /// - Returns: The cached image or nil if not found/expired
    func getCachedImage(for key: String) async -> Image? {
        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let cachedData = self.imageCache[key], !cachedData.isExpired,
                   let uiImage = UIImage(data: cachedData.imageData) {
                    continuation.resume(returning: Image(uiImage: uiImage))
                    return
                }

                if let diskCachedData = self.loadImageFromDisk(for: key) {
                    self.imageCache[key] = diskCachedData
                    if let uiImage = UIImage(data: diskCachedData.imageData) {
                        continuation.resume(returning: Image(uiImage: uiImage))
                        return
                    }
                }

                continuation.resume(returning: nil)
            }
        }
    }

    /// Get cached image data for a given key (returns raw Data instead of SwiftUI Image)
    /// - Parameter key: Unique identifier for the image
    /// - Returns: The cached image data or nil if not found/expired
    func getCachedImageData(for key: String) async -> Data? {
        await withCheckedContinuation { continuation in
            cacheQueue.async { [weak self] in
                guard let self = self else {
                    continuation.resume(returning: nil)
                    return
                }

                if let cachedData = self.imageCache[key], !cachedData.isExpired {
                    continuation.resume(returning: cachedData.imageData)
                    return
                }

                if let diskCachedData = self.loadImageFromDisk(for: key) {
                    self.imageCache[key] = diskCachedData
                    continuation.resume(returning: diskCachedData.imageData)
                    return
                }

                continuation.resume(returning: nil)
            }
        }
    }
    
    /// Cache an image with a given key
    /// - Parameters:
    ///   - imageData: The image data to cache
    ///   - key: Unique identifier for the image
    func cacheImage(_ imageData: Data, for key: String) {
        let logger = self.logger
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

            logger.log("Cached image for key: \(key)", level: .debug, category: .cache)
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
            
            self.logger.log("Cleared all image cache", level: .info, category: .cache)
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
            
            self.logger.log("Removed cached image for key: \(key)", level: .debug, category: .cache)
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
                self.logger.log("Cleaned \(expiredKeys.count) expired image cache entries", level: .info, category: .cache)
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
            logger.log("Failed to calculate disk usage: \(error)", level: .error, category: .cache)
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
            logger.log("Failed to calculate disk usage: \(error)", level: .error, category: .cache)
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
        let logger = self.logger
        cacheQueue.async { [weak self] in
            guard let self = self else { return }

            for key in keys {
                // Check if already cached
                if self.hasCachedImage(for: key) {
                    continue
                }

                // For now, we can't preload without the actual image data
                // This method could be extended to work with a preloader service
                logger.log("Preload requested for key: \(key) (already cached or not available)", level: .debug, category: .cache)
            }
        }
    }
    
    // MARK: - Private Methods
    
    private func loadCacheFromDisk() {
        do {
            let fileURLs = try fileManager.contentsOfDirectory(at: cacheDirectory, includingPropertiesForKeys: nil)
            
            for fileURL in fileURLs {
                if fileURL.pathExtension == "cache" {
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
            
            logger.log("Loaded \(imageCache.count) cached images from disk", level: .info, category: .cache)
        } catch {
            logger.log("Failed to load cache from disk: \(error)", level: .error, category: .cache)
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
            logger.log("Failed to save image to disk: \(error)", level: .error, category: .cache)
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
                // Remove expired file using the sanitized key
                let expiredFileURL = cacheDirectory.appendingPathComponent("\(sanitizedKey).cache")
                try? fileManager.removeItem(at: expiredFileURL)
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
        logger.log("App terminating, ensuring cache is saved to disk", level: .info, category: .cache)
        // Force save all cached data to disk
        for (_, cachedData) in imageCache {
            saveImageToDisk(cachedData)
        }
    }
    
    @objc private func handleAppDidEnterBackground() {
        logger.log("App entering background, saving cache to disk", level: .info, category: .cache)
        // The cache is already saved to disk, but we can perform additional cleanup
        cleanExpiredCache()
    }
    
    @objc private func handleAppWillEnterForeground() {
        logger.log("App entering foreground, loading cache from disk", level: .info, category: .cache)
        // Reload cache from disk in case it was cleared by the system
        loadCacheFromDisk()
    }
    
    deinit {
        // Remove observers when the service is deallocated
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func handleMemoryPressure() {
        logger.log("Memory pressure detected, clearing memory cache", level: .warning, category: .cache)
        
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
            logger.log("Removed \(keysToRemove.count) images from memory cache due to memory pressure", level: .info, category: .cache)
        }
    }
}

// MARK: - Convenience Extensions

extension ImageCacheService {
    /// Get a cached image for a spot ID
    /// - Parameter spotId: The spot identifier
    /// - Returns: The cached image or nil if not found
    func getCachedSpotImage(for spotId: String) async -> Image? {
        await getCachedImage(for: "spot_\(spotId)")
    }

    /// Get cached image data for a spot ID (returns raw Data instead of SwiftUI Image)
    /// - Parameter spotId: The spot identifier
    /// - Returns: The cached image data or nil if not found
    func getCachedSpotImageData(for spotId: String) async -> Data? {
        await getCachedImageData(for: "spot_\(spotId)")
    }
    
    /// Cache a spot image
    /// - Parameters:
    ///   - imageData: The image data to cache
    ///   - spotId: The spot identifier
    func cacheSpotImage(_ imageData: Data, for spotId: String) {
        cacheImage(imageData, for: "spot_\(spotId)")
    }
    
    /// Get a cached image for a surf report
    /// - Parameter imageKey: The surf report image key
    /// - Returns: The cached image or nil if not found
    func getCachedSurfReportImage(for imageKey: String) async -> Image? {
        await getCachedImage(for: "report_\(imageKey)")
    }

    /// Get cached image data for a surf report (returns raw Data instead of SwiftUI Image)
    /// - Parameter imageKey: The surf report image key
    /// - Returns: The cached image data or nil if not found
    func getCachedSurfReportImageData(for imageKey: String) async -> Data? {
        await getCachedImageData(for: "report_\(imageKey)")
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
