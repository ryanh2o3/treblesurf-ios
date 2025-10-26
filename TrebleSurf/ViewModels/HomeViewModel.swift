import Foundation
import Combine
import UIKit
import SwiftUI
import AVFoundation

// MARK: - Cache Models
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

// MARK: - Weather Buoy Model
struct WeatherBuoy: Identifiable {
    let id = UUID()
    let name: String
    let waveHeight: String
    let windDirection: String
    let waveDirection: String
    let wavePeriod: String
    let temperature: String
    let waterTemperature: String
    let isLoading: Bool
    
    init(name: String, waveHeight: String = "Loading...", windDirection: String = "Loading...", waveDirection: String = "Loading...", wavePeriod: String = "Loading...",  temperature: String = "Loading...", waterTemperature: String = "Loading...", isLoading: Bool = true) {
        self.name = name
        self.waveHeight = waveHeight
        self.windDirection = windDirection
        self.waveDirection = waveDirection
        self.wavePeriod = wavePeriod
        self.temperature = temperature
        self.waterTemperature = waterTemperature
        self.isLoading = isLoading
    }
}

@MainActor
class HomeViewModel: ObservableObject {
    @Published var currentCondition: CurrentCondition?
    @Published var featuredSpots: [FeaturedSpot] = []
    @Published var recentReports: [SurfReport] = []
    @Published var weatherBuoys: [WeatherBuoy] = []
    @Published var spots: [SpotData] = []
    @Published var isLoadingConditions: Bool = true
    
    // MARK: - Dependencies
    private let config: AppConfigurationProtocol
    private let apiClient: APIClientProtocol
    private let buoyCacheService = BuoyCacheService.shared
    
    // MARK: - Caching Properties
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    init(
        config: AppConfigurationProtocol = AppConfiguration.shared,
        apiClient: APIClientProtocol = APIClient.shared
    ) {
        self.config = config
        self.apiClient = apiClient
        
        // Initial setup
        setupCacheCleanup()
        setupWeatherBuoys()
        
        // Subscribe to buoy cache updates
        buoyCacheService.$cachedBuoyData
            .sink { [weak self] _ in
                self?.updateWeatherBuoysFromCache()
            }
            .store(in: &cancellables)
    }
    
    var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    // MARK: - Weather Buoys Setup
    private func setupWeatherBuoys() {
        weatherBuoys = config.defaultBuoys.map { WeatherBuoy(name: $0) }
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
    func loadData() {
        loadMockData()
        fetchSpots()
        fetchSurfReports()
        fetchWeatherBuoys()
    }
    
    @MainActor
    func refreshData() async {
        // Clear cache and reload all data
        surfReportsCache.removeAll()
        buoyCacheService.clearCache()
        fetchSpots()
        fetchSurfReports()
        fetchWeatherBuoys()
        updateCurrentConditionsFromBallyhiernan()
    }
    
    func refreshSurfReports() {
        // Force refresh by clearing cache and fetching again
        let cacheKey = getCacheKey(country: "Ireland", region: "Donegal")
        surfReportsCache.removeValue(forKey: cacheKey)
        fetchSurfReports()
    }
    
    // MARK: - Private Methods
    private func fetchSpots() {
        apiClient.fetchSpots(country: config.defaultCountry, region: config.defaultRegion) { [weak self] result in
            switch result {
            case .success(let spots):
                Task { @MainActor [weak self] in
                    self?.spots = spots
                    self?.updateCurrentConditionsFromBallyhiernan()
                }
            case .failure(let error):
                print("Failed to fetch spots: \(error.localizedDescription)")
            }
        }
    }
    
    private func updateCurrentConditionsFromBallyhiernan() {
        // Always use Ballyhiernan Spot for current conditions
        let ballyhiernanSpot = "Ballyhiernan"
        
        // Set loading state
        isLoadingConditions = true
        
        // Fetch current conditions for Ballyhiernan
        apiClient.fetchCurrentConditions(country: config.defaultCountry, region: config.defaultRegion, spot: ballyhiernanSpot) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self.isLoadingConditions = false
                
                switch result {
                case .success(let conditionsResponses):
                    if let firstCondition = conditionsResponses.first {
                        let condition = self.createCurrentCondition(from: firstCondition.data, spotName: ballyhiernanSpot)
                        self.currentCondition = condition
                    } else {
                        // Fallback to mock data if no conditions available
                        self.currentCondition = CurrentCondition(
                            waveHeight: "1.5m",
                            windDirection: "W",
                            windSpeed: "15 km/h",
                            temperature: "18°C",
                            summary: "No data available for \(ballyhiernanSpot)"
                        )
                    }
                case .failure(let error):
                    print("Failed to fetch current conditions for Ballyhiernan: \(error.localizedDescription)")
                    // Fallback to mock data on error
                    self.currentCondition = CurrentCondition(
                        waveHeight: "1.5m",
                        windDirection: "W",
                        windSpeed: "15 km/h",
                        temperature: "18°C",
                        summary: "Unable to load conditions for \(ballyhiernanSpot)"
                    )
                }
            }
        }
    }
    
    private func createCurrentCondition(from data: ConditionData, spotName: String) -> CurrentCondition {
        // Keep wave height in meters
        let waveHeightString = String(format: "%.1fm", data.surfSize)
        
        // Convert wind direction from degrees to cardinal direction
        let windDirectionString = getWindDirectionString(from: data.windDirection)
        
        // Convert wind speed from m/s to km/h
        let windSpeedInKmh = data.windSpeed * 3.6
        let windSpeedString = String(format: "%.0f km/h", windSpeedInKmh)
        
        // Keep temperature in Celsius
        let temperatureString = String(format: "%.0f°C", data.temperature)
        
        // Create summary based on actual data
        let summary = "Current conditions at \(spotName): \(data.surfMessiness) waves, \(data.formattedRelativeWindDirection) wind"
        
        return CurrentCondition(
            waveHeight: waveHeightString,
            windDirection: windDirectionString,
            windSpeed: windSpeedString,
            temperature: temperatureString,
            summary: summary
        )
    }
    
    private func getWindDirectionString(from degrees: Double) -> String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE", "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((degrees + 11.25) / 22.5) % 16
        return directions[index]
    }
    
    private func fetchWeatherBuoys() {
        let buoyNames = config.defaultBuoys
        
        // Check cache first
        if let cachedData = buoyCacheService.getCachedBuoyData(for: buoyNames) {
            updateWeatherBuoys(with: cachedData)
            return
        }
        
        // Fetch from API if not cached
        apiClient.fetchBuoyData(buoyNames: buoyNames) { [weak self] result in
            switch result {
            case .success(let buoyResponses):
                Task { @MainActor [weak self] in
                    guard let self = self else { return }
                    // Cache the data for future use
                    self.buoyCacheService.cacheBuoyData(buoyResponses)
                    self.updateWeatherBuoys(with: buoyResponses)
                }
            case .failure(let error):
                print("Failed to fetch buoy data: \(error.localizedDescription)")
                // Update buoys with error state
                Task { @MainActor [weak self] in
                    self?.updateWeatherBuoysWithError()
                }
            }
        }
    }
    
    private func updateWeatherBuoysFromCache() {
        let buoyNames = config.defaultBuoys
        if let cachedData = buoyCacheService.getCachedBuoyData(for: buoyNames) {
            updateWeatherBuoys(with: cachedData)
        }
    }
    
    private func updateWeatherBuoys(with responses: [BuoyResponse]) {
        for (index, response) in responses.enumerated() {
            if index < weatherBuoys.count {
                let buoy = createWeatherBuoy(from: response)
                weatherBuoys[index] = buoy
            }
        }
    }
    
    private func updateWeatherBuoysWithError() {
        for index in weatherBuoys.indices {
            weatherBuoys[index] = WeatherBuoy(
                name: weatherBuoys[index].name,
                waveHeight: "Error",
                windDirection: "Error",
                temperature: "Error",
                waterTemperature: "Error",
                isLoading: false
            )
        }
    }
    
    private func createWeatherBuoy(from response: BuoyResponse) -> WeatherBuoy {
        // Use the same robust validation logic as BuoysViewModel
        let waveHeight = response.WaveHeight ?? 0.0
        let wavePeriod = response.MaxPeriod ?? 0.0  // Use MaxPeriod instead of WavePeriod
        let windDirection = response.WindDirection ?? 0
        let waveDirection = response.MeanWaveDirection ?? 0
        let temperature = response.AirTemperature ?? 0.0
        let waterTemperature = response.SeaTemperature ?? 0.0
        
        // Validate numeric values and provide fallbacks for invalid data
        let validWaveHeight = waveHeight.isFinite && waveHeight >= 0 ? waveHeight : 0.0
        let validWavePeriod = wavePeriod.isFinite && wavePeriod >= 0 ? wavePeriod : 0.0
        let validWindDirection = (0...360).contains(windDirection) ? windDirection : 0
        let validWaveDirection = (0...360).contains(waveDirection) ? waveDirection : 0
        let validTemperature = temperature.isFinite ? temperature : 0.0
        let validWaterTemperature = waterTemperature.isFinite ? waterTemperature : 0.0
        
        // Format strings with validation
        let waveHeightString = validWaveHeight > 0 ? String(format: "%.1fm", validWaveHeight) : "N/A"
        let wavePeriodString = validWavePeriod > 0 ? String(format: "%.1fs", validWavePeriod) : "N/A"
        let windDirectionString = validWindDirection > 0 ? String(format: "%d°", validWindDirection) : "N/A"
        let waveDirectionString = validWaveDirection > 0 ? String(format: "%d°", validWaveDirection) : "N/A"
        let temperatureString = validTemperature != 0 ? String(format: "%.1f°C", validTemperature) : "N/A"
        let waterTemperatureString = validWaterTemperature != 0 ? String(format: "%.1f°C", validWaterTemperature) : "N/A"
        
        return WeatherBuoy(
            name: response.name,
            waveHeight: waveHeightString,
            windDirection: windDirectionString,
            waveDirection: waveDirectionString,
            wavePeriod: wavePeriodString,
            temperature: temperatureString,
            waterTemperature: waterTemperatureString,
            isLoading: false
        )
    }
    
    private func fetchSurfReports() {
        // Check cache first
        if let cachedReports = getCachedReports(country: config.defaultCountry, region: config.defaultRegion) {
            recentReports = cachedReports
            return
        }
        
        // First fetch all spots, then get reports for each spot
        apiClient.fetchSpots(country: config.defaultCountry, region: config.defaultRegion) { [weak self] result in
            switch result {
            case .success(let spots):
                // Fetch reports for each spot
                self?.fetchReportsForAllSpots(spots: spots)
            case .failure(let error):
                print("Failed to fetch spots: \(error.localizedDescription)")
            }
        }
    }
    
    private func fetchReportsForAllSpots(spots: [SpotData]) {
        var allReports: [SurfReport] = []
        let group = DispatchGroup()
        
        for spot in spots {
            group.enter()
            apiClient.fetchSurfReports(country: config.defaultCountry, region: config.defaultRegion, spot: spot.name) { [weak self] result in
                defer { group.leave() }
                
                switch result {
                case .success(let responses):
                    let outputDateFormatter = DateFormatter()
                    outputDateFormatter.dateFormat = "d MMM, h:mma"
                    outputDateFormatter.locale = Locale(identifier: "en_US_POSIX")

                    let spotReports = responses.map { [weak self] response in
                        // Parse the timestamp with multiple format support
                        let date = self?.parseTimestamp(response.time)
                        let formattedTime = date != nil ? outputDateFormatter.string(from: date!) : "Invalid Date"
                        // Extract just the spot name from countryRegionSpot
                        let spotName = response.countryRegionSpot.components(separatedBy: "_").last ?? response.countryRegionSpot
                        
                        var report = SurfReport(
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
                            countryRegionSpot: spotName, // Now just the spot name
                            dateReported: response.dateReported,
                            mediaType: response.mediaType,
                            iosValidated: response.iosValidated
                        )
                        
                        if let imageKey = response.imageKey, !imageKey.isEmpty {
                            // Debug: print the imageKey to see its format
                            print("Debug - ImageKey from API: '\(imageKey)'")
                            // Use the imageKey directly as it should already contain the full path
                            self?.fetchImage(for: imageKey) { imageData in
                                Task { @MainActor [weak self] in
                                    report.imageData = imageData?.imageData
                                    self?.objectWillChange.send() // Notify UI of changes
                                }
                            }
                        }
                        
                        // Video handling is now done via presigned URLs in the detail view
                        // No need to fetch video data here
                        
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
            
            self.recentReports = allReports
            
            // Cache the results
            self.cacheReports(allReports, country: self.config.defaultCountry, region: self.config.defaultRegion)
            
            // Preload surf report images for better user experience
            let imageKeys = allReports.compactMap { $0.imageKey }.filter { !$0.isEmpty }
            if !imageKeys.isEmpty {
                print("📱 Preloading \(imageKeys.count) surf report images")
                // Note: We can't preload without the actual image data
                // The images will be cached when they're first accessed
            }
        }
    }
        
    private func fetchImage(for key: String, completion: @escaping (SurfReportImageResponse?) -> Void) {
        // First, check the dedicated image cache
        ImageCacheService.shared.getCachedSurfReportImageData(for: key) { cachedImageData in
            if let cachedImageData = cachedImageData {
                print("✅ Using cached surf report image for key: \(key)")
                // Create a mock response with the cached image data
                let mockResponse = SurfReportImageResponse(imageData: cachedImageData.base64EncodedString(), contentType: "image/jpeg")
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
                        print("⚠️ [HOME_VIEWMODEL] Image key \(key) exists but no image data returned - likely missing from S3")
                        completion(nil)
                    }
                case .failure(let error):
                    print("❌ [HOME_VIEWMODEL] Failed to fetch image for key \(key): \(error.localizedDescription)")
                    completion(nil)
                }
            }
        }
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
        
        // Format 4: Try parsing as a Date object directly (for debugging)
        print("Failed to parse timestamp: \(timestamp)")
        return nil
    }
    
    private func loadMockData() {
        // Load sample data with correct units
        currentCondition = CurrentCondition(
            waveHeight: "1.5m",
            windDirection: "W",
            windSpeed: "12 km/h",
            temperature: "18°C",
            summary: "Loading conditions..."
        )
        
        featuredSpots = [
            FeaturedSpot(
                id: "1",
                name: "Sample Beach",
                imageURL: nil,
                waveHeight: "3ft",
                quality: "Good",
                distance: "5 mi"
            )
        ]
        
    }
    
    // MARK: - Video Handling
    
    // Video handling is now done via presigned URLs in the detail view
    // No need for local video fetching or thumbnail generation
}

// Basic model structures
struct CurrentCondition {
    let waveHeight: String
    let windDirection: String
    let windSpeed: String
    let temperature: String
    let summary: String
}

struct FeaturedSpot: Identifiable {
    let id: String
    let name: String
    let imageURL: URL?
    let waveHeight: String
    let quality: String
    let distance: String
}
