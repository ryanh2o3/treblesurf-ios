import Foundation
import Combine
import UIKit
import SwiftUI

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

class HomeViewModel: ObservableObject {
    @Published var currentCondition: CurrentCondition?
    @Published var featuredSpots: [FeaturedSpot] = []
    @Published var recentReports: [SurfReport] = []
    @Published var weatherBuoys: [WeatherBuoy] = []
    @Published var spots: [SpotData] = []
    @Published var isLoadingConditions: Bool = true
    
    // MARK: - Caching Properties
    private var surfReportsCache: [String: CachedSurfReports] = [:]
    private let cacheQueue = DispatchQueue(label: "com.treblesurf.cache", qos: .utility)
    private var cancellables = Set<AnyCancellable>()
    
    var formattedCurrentDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: Date())
    }
    
    init() {
        // Initial setup
        setupCacheCleanup()
        setupWeatherBuoys()
    }
    
    // MARK: - Weather Buoys Setup
    private func setupWeatherBuoys() {
        weatherBuoys = [
            WeatherBuoy(name: "M4"),
            WeatherBuoy(name: "M6")
        ]
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
        APIClient.shared.fetchSpots(country: "Ireland", region: "Donegal") { [weak self] result in
            switch result {
            case .success(let spots):
                DispatchQueue.main.async {
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
        DispatchQueue.main.async {
            self.isLoadingConditions = true
        }
        
        // Fetch current conditions for Ballyhiernan
        APIClient.shared.fetchCurrentConditions(country: "Ireland", region: "Donegal", spot: ballyhiernanSpot) { [weak self] result in
            DispatchQueue.main.async {
                self?.isLoadingConditions = false
                
                switch result {
                case .success(let conditionsResponses):
                    if let firstCondition = conditionsResponses.first {
                        let condition = self?.createCurrentCondition(from: firstCondition.data, spotName: ballyhiernanSpot)
                        self?.currentCondition = condition
                    } else {
                        // Fallback to mock data if no conditions available
                        self?.currentCondition = CurrentCondition(
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
                    self?.currentCondition = CurrentCondition(
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
        let buoyNames = ["M4", "M6"]
        
        APIClient.shared.fetchBuoyData(buoyNames: buoyNames) { [weak self] result in
            switch result {
            case .success(let buoyResponses):
                DispatchQueue.main.async {
                    self?.updateWeatherBuoys(with: buoyResponses)
                }
            case .failure(let error):
                print("Failed to fetch buoy data: \(error.localizedDescription)")
                // Update buoys with error state
                DispatchQueue.main.async {
                    self?.updateWeatherBuoysWithError()
                }
            }
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
        let waveHeight = response.WaveHeight != nil ? String(format: "%.1fm", response.WaveHeight!) : "N/A"
        let wavePeriod = response.WavePeriod != nil ? String(format: "%.1fs", response.WavePeriod!) : "N/A"
        let windDirection = response.WindDirection != nil ? String(format: "%d°", response.WindDirection!) : "N/A"
        let waveDirection = response.MeanWaveDirection != nil ? String(format: "%d°", response.MeanWaveDirection!) : "N/A"
        let temperature = response.AirTemperature != nil ? String(format: "%.1f°C", response.AirTemperature!) : "N/A"
        let waterTemperature = response.SeaTemperature != nil ? String(format: "%.1f°C", response.SeaTemperature!) : "N/A"
        
        return WeatherBuoy(
            name: response.name,
            waveHeight: waveHeight,
            windDirection: windDirection,
            waveDirection: waveDirection,
            wavePeriod: wavePeriod,
            temperature: temperature,
            waterTemperature: waterTemperature,
            isLoading: false
        )
    }
    
    private func fetchSurfReports() {
        // Check cache first
        if let cachedReports = getCachedReports(country: "Ireland", region: "Donegal") {
            DispatchQueue.main.async { [weak self] in
                self?.recentReports = cachedReports
            }
            return
        }
        
        // First fetch all spots, then get reports for each spot
        APIClient.shared.fetchSpots(country: "Ireland", region: "Donegal") { [weak self] result in
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
            APIClient.shared.fetchSurfReports(country: "Ireland", region: "Donegal", spot: spot.name) { [weak self] result in
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
                            messiness: response.messiness,
                            quality: response.quality,
                            reporter: response.reporter,
                            surfSize: response.surfSize,
                            time: formattedTime,
                            userEmail: response.userEmail,
                            windAmount: response.windAmount,
                            windDirection: response.windDirection,
                            countryRegionSpot: spotName, // Now just the spot name
                            dateReported: response.dateReported
                        )
                        
                        if let imageKey = response.imageKey, !imageKey.isEmpty {
                            // Debug: print the imageKey to see its format
                            print("Debug - ImageKey from API: '\(imageKey)'")
                            // Use the imageKey directly as it should already contain the full path
                            self?.fetchImage(for: imageKey) { imageData in
                                DispatchQueue.main.async {
                                    report.imageData = imageData?.imageData
                                    self?.objectWillChange.send() // Notify UI of changes
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
            
            self.recentReports = allReports
            
            // Cache the results
            self.cacheReports(allReports, country: "Ireland", region: "Donegal")
            
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
            APIClient.shared.getReportImage(key: key) { result in
                switch result {
                case .success(let imageData):
                    // Cache the image for future use
                    if let decodedImageData = Data(base64Encoded: imageData.imageData),
                       let uiImage = UIImage(data: decodedImageData) {
                        if let pngData = uiImage.pngData() {
                            ImageCacheService.shared.cacheSurfReportImage(pngData, for: key)
                        }
                    }
                    completion(imageData)
                case .failure(let error):
                    print("Failed to fetch image for key \(key): \(error.localizedDescription)")
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
