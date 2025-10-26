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
    private let surfReportService: SurfReportService
    private let weatherBuoyService: WeatherBuoyService
    private let buoyCacheService = BuoyCacheService.shared
    
    private var cancellables = Set<AnyCancellable>()
    
    init(
        config: AppConfigurationProtocol = AppConfiguration.shared,
        apiClient: APIClientProtocol = APIClient.shared,
        surfReportService: SurfReportService = SurfReportService.shared,
        weatherBuoyService: WeatherBuoyService = WeatherBuoyService.shared
    ) {
        self.config = config
        self.apiClient = apiClient
        self.surfReportService = surfReportService
        self.weatherBuoyService = weatherBuoyService
        
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
        let validWindDirection = DataFormatter.validateDirection(windDirection)
        let validWaveDirection = DataFormatter.validateDirection(waveDirection)
        let validTemperature = DataFormatter.validateNumericValue(temperature)
        let validWaterTemperature = DataFormatter.validateNumericValue(waterTemperature)
        
        // Format strings with validation
        let waveHeightString = validWaveHeight > 0 ? DataFormatter.formatWaveHeight(validWaveHeight) : "N/A"
        let wavePeriodString = validWavePeriod > 0 ? DataFormatter.formatWavePeriod(validWavePeriod) : "N/A"
        let windDirectionString = DataFormatter.formatWindDirection(validWindDirection)
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
        // Use SurfReportService to fetch and cache reports
        surfReportService.fetchSurfReports(
            country: config.defaultCountry,
            region: config.defaultRegion
        ) { [weak self] result in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                switch result {
                case .success(let reports):
                    self.recentReports = reports
                case .failure(let error):
                    print("Failed to fetch surf reports: \(error.localizedDescription)")
                }
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
