import Foundation
import Combine
import UIKit
import SwiftUI
import AVFoundation

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
class HomeViewModel: BaseViewModel {
    @Published var currentCondition: CurrentCondition?
    @Published var featuredSpots: [FeaturedSpot] = []
    @Published var recentReports: [SurfReport] = []
    @Published var weatherBuoys: [WeatherBuoy] = []
    @Published var spots: [SpotData] = []
    @Published var isLoadingConditions: Bool = true
    @Published var isLoadingReports: Bool = true
    @Published var isLoadingBuoys: Bool = true
    
    // MARK: - Dependencies
    private let config: AppConfigurationProtocol
    private let apiClient: APIClientProtocol
    private let surfReportService: SurfReportService
    private let weatherBuoyService: WeatherBuoyService
    private let buoyCacheService: BuoyCacheService
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        config: AppConfigurationProtocol,
        apiClient: APIClientProtocol,
        surfReportService: SurfReportService,
        weatherBuoyService: WeatherBuoyService,
        buoyCacheService: BuoyCacheService
    ) {
        self.config = config
        self.apiClient = apiClient
        self.surfReportService = surfReportService
        self.weatherBuoyService = weatherBuoyService
        self.buoyCacheService = buoyCacheService
        
        super.init()
        
        // Initial setup
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
        surfReportService.clearAllCache()
        buoyCacheService.clearCache()
        fetchSpots()
        fetchSurfReports()
        fetchWeatherBuoys()
        updateCurrentConditionsFromBallyhiernan()
    }
    
    func refreshSurfReports() {
        // Force refresh by clearing cache and fetching again
        surfReportService.clearCache(country: config.defaultCountry, region: config.defaultRegion)
        fetchSurfReports()
    }
    
    // MARK: - Private Methods
    private func fetchSpots() {
        logger.log("Fetching spots for \(config.defaultCountry)/\(config.defaultRegion)", level: .info, category: .api)
        
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let spots = try await self.apiClient.fetchSpots(country: self.config.defaultCountry, region: self.config.defaultRegion)
                self.logger.log("Successfully fetched \(spots.count) spots", level: .info, category: .api)
                self.spots = spots
                self.updateCurrentConditionsFromBallyhiernan()
            } catch {
                self.logger.log("Failed to fetch spots: \(error.localizedDescription)", level: .error, category: .api)
            }
        }
    }
    
    private func updateCurrentConditionsFromBallyhiernan() {
        // Always use Ballyhiernan Spot for current conditions
        let ballyhiernanSpot = "Ballyhiernan"
        
        logger.log("Fetching current conditions for \(ballyhiernanSpot)", level: .info, category: .api)
        
        // Set loading state
        isLoadingConditions = true
        
        // Fetch current conditions for Ballyhiernan
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let conditionsResponses = try await self.apiClient.fetchCurrentConditions(country: self.config.defaultCountry, region: self.config.defaultRegion, spot: ballyhiernanSpot)
                self.isLoadingConditions = false
                if let firstCondition = conditionsResponses.first {
                    self.logger.log("Successfully fetched conditions for \(ballyhiernanSpot)", level: .debug, category: .api)
                    let condition = self.createCurrentCondition(from: firstCondition.data, spotName: ballyhiernanSpot)
                    self.currentCondition = condition
                } else {
                    self.logger.log("No conditions available for \(ballyhiernanSpot)", level: .warning, category: .api)
                    // Fallback to mock data if no conditions available
                    self.currentCondition = CurrentCondition(
                        waveHeight: "1.5m",
                        windDirection: "W",
                        windSpeed: "15 km/h",
                        temperature: "18°C",
                        summary: "No data available for \(ballyhiernanSpot)"
                    )
                }
            } catch {
                self.isLoadingConditions = false
                self.logger.log("Failed to fetch current conditions for \(ballyhiernanSpot): \(error.localizedDescription)", level: .error, category: .api)
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
    
    private func createCurrentCondition(from data: ConditionData, spotName: String) -> CurrentCondition {
        // Keep wave height in meters
        let waveHeightString = DataFormatter.formatWaveHeight(data.surfSize)
        
        // Convert wind direction from degrees to cardinal direction
        let windDirectionString = DataFormatter.getWindDirectionString(from: data.windDirection)
        
        // Convert wind speed from m/s to km/h
        let windSpeedString = DataFormatter.formatWindSpeed(data.windSpeed)
        
        // Keep temperature in Celsius
        let temperatureString = DataFormatter.formatTemperature(data.temperature)
        
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
    
    private func fetchWeatherBuoys() {
        let buoyNames = config.defaultBuoys
        isLoadingBuoys = true
        
        logger.log("Fetching weather buoy data for \(buoyNames.count) buoys", level: .info, category: .api)
        
        // Check cache first
        if let cachedData = buoyCacheService.getCachedBuoyData(for: buoyNames) {
            logger.log("Using cached buoy data", level: .debug, category: .cache)
            updateWeatherBuoys(with: cachedData)
            isLoadingBuoys = false
            return
        }
        
        // Fetch from API if not cached
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let buoyResponses = try await self.apiClient.fetchBuoyData(buoyNames: buoyNames)
                self.logger.log("Successfully fetched buoy data for \(buoyResponses.count) buoys", level: .info, category: .api)
                // Cache the data for future use
                self.buoyCacheService.cacheBuoyData(buoyResponses)
                self.updateWeatherBuoys(with: buoyResponses)
                self.isLoadingBuoys = false
            } catch {
                self.logger.log("Failed to fetch buoy data: \(error.localizedDescription)", level: .error, category: .api)
                // Update buoys with error state
                self.updateWeatherBuoysWithError()
                self.isLoadingBuoys = false
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
        // Use DataFormatter for validation and formatting
        let waveHeight = response.WaveHeight ?? 0.0
        let wavePeriod = response.MaxPeriod ?? 0.0  // Use MaxPeriod instead of WavePeriod
        let windDirection = response.WindDirection ?? 0
        let waveDirection = response.MeanWaveDirection ?? 0
        let temperature = response.AirTemperature ?? 0.0
        let waterTemperature = response.SeaTemperature ?? 0.0
        
        // Validate numeric values using DataFormatter
        let validWaveHeight = DataFormatter.validateNumericValue(waveHeight)
        let validWavePeriod = DataFormatter.validateNumericValue(wavePeriod)
        let validWaveDirection = DataFormatter.validateDirection(waveDirection)
        let validTemperature = DataFormatter.validateNumericValue(temperature)
        let validWaterTemperature = DataFormatter.validateNumericValue(waterTemperature)
        
        // Format strings with validation
        let waveHeightString = validWaveHeight > 0 ? DataFormatter.formatWaveHeight(validWaveHeight) : "N/A"
        let wavePeriodString = validWavePeriod > 0 ? DataFormatter.formatWavePeriod(validWavePeriod) : "N/A"
        let windDirectionString = DataFormatter.formatWindDirection(DataFormatter.validateDirection(windDirection))
        let waveDirectionString = DataFormatter.formatWindDirection(validWaveDirection)
        let temperatureString = validTemperature != 0 ? DataFormatter.formatTemperature(validTemperature) : "N/A"
        let waterTemperatureString = validWaterTemperature != 0 ? DataFormatter.formatTemperature(validWaterTemperature) : "N/A"
        
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
        isLoadingReports = true
        
        logger.log("Fetching surf reports for \(config.defaultCountry)/\(config.defaultRegion)", level: .info, category: .api)
        
        // Use SurfReportService to fetch and cache reports
        Task { [weak self] in
            guard let self = self else { return }
            do {
                let reports = try await self.surfReportService.fetchSurfReports(
                    country: self.config.defaultCountry,
                    region: self.config.defaultRegion
                )
                self.logger.log("Successfully fetched \(reports.count) surf reports", level: .info, category: .api)
                self.recentReports = reports
                self.isLoadingReports = false
            } catch {
                self.logger.log("Failed to fetch surf reports: \(error.localizedDescription)", level: .error, category: .api)
                self.isLoadingReports = false
            }
        }
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
