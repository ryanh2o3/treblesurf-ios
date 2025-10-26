//
//  WeatherBuoyService.swift
//  TrebleSurf
//
//  Created by Cursor
//

import Foundation
import Combine

/// Service for fetching and processing weather buoy data
class WeatherBuoyService: ObservableObject {
    static let shared = WeatherBuoyService()
    
    private let apiClient: APIClientProtocol
    private let buoyCacheService: BuoyCacheService
    private var cancellables = Set<AnyCancellable>()
    
    init(
        apiClient: APIClientProtocol = APIClient.shared,
        buoyCacheService: BuoyCacheService = BuoyCacheService.shared
    ) {
        self.apiClient = apiClient
        self.buoyCacheService = buoyCacheService
    }
    
    // MARK: - Public Methods
    
    /// Fetch buoy data for specified buoy names
    /// - Parameters:
    ///   - buoyNames: Array of buoy names to fetch
    ///   - completion: Completion handler with array of BuoyResponse objects
    func fetchBuoyData(
        buoyNames: [String],
        completion: @escaping (Result<[BuoyResponse], Error>) -> Void
    ) {
        // Check cache first
        if let cachedData = buoyCacheService.getCachedBuoyData(for: buoyNames) {
            completion(.success(cachedData))
            return
        }
        
        // Fetch from API if not cached
        apiClient.fetchBuoyData(buoyNames: buoyNames) { [weak self] result in
            switch result {
            case .success(let buoyResponses):
                // Cache the data for future use
                self?.buoyCacheService.cacheBuoyData(buoyResponses)
                completion(.success(buoyResponses))
            case .failure(let error):
                print("Failed to fetch buoy data: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    /// Fetch buoy locations for a region
    /// - Parameters:
    ///   - region: Region name (e.g., "NorthAtlantic")
    ///   - completion: Completion handler with array of BuoyLocation objects
    func fetchBuoyLocations(
        region: String,
        completion: @escaping (Result<[BuoyLocation], Error>) -> Void
    ) {
        apiClient.fetchBuoys(region: region, completion: completion)
    }
    
    /// Fetch historical data for a specific buoy
    /// - Parameters:
    ///   - buoyName: Name of the buoy
    ///   - completion: Completion handler with array of historical BuoyResponse objects
    func fetchHistoricalData(
        for buoyName: String,
        completion: @escaping (Result<[BuoyResponse], Error>) -> Void
    ) {
        apiClient.fetchLast24HoursBuoyData(buoyName: buoyName, completion: completion)
    }
    
    // MARK: - Data Transformation
    
    /// Convert BuoyResponse to domain model
    /// - Parameters:
    ///   - response: API response object
    ///   - historicalData: Historical wave data points
    ///   - locationData: Location information for the buoy
    /// - Returns: Buoy domain model or nil if conversion fails
    func convertToBuoy(
        response: BuoyResponse,
        historicalData: [WaveDataPoint] = [],
        locationData: BuoyLocation? = nil
    ) -> Buoy? {
        print("Debug: convertToBuoy called for '\(response.name)'")
        
        // Validate that we have the minimum required data
        guard !response.name.isEmpty else {
            print("Warning: Buoy response missing name, skipping")
            return nil
        }
        
        // Log any unusual values for debugging
        if let maxPeriod = response.MaxPeriod, !maxPeriod.isFinite {
            print("Warning: Buoy \(response.name) has invalid MaxPeriod: \(maxPeriod)")
        }
        
        if let maxHeight = response.MaxHeight, !maxHeight.isFinite {
            print("Warning: Buoy \(response.name) has invalid MaxHeight: \(maxHeight)")
        }
        
        // Extract region from region_buoy
        let regionParts = response.region_buoy.split(separator: "_")
        let organization = regionParts.first.map(String.init) ?? "Unknown"
        
        // Format the timestamp with better error handling
        let dateFormatter = ISO8601DateFormatter()
        let date: Date
        let lastUpdated: String
        
        if let dataDateTime = response.dataDateTime,
           let parsedDate = dateFormatter.date(from: dataDateTime) {
            date = parsedDate
            let minutesAgo = Int(Date().timeIntervalSince(date) / 60)
            lastUpdated = "\(minutesAgo) minutes ago"
        } else {
            date = Date()
            lastUpdated = "Unknown"
            print("Warning: Buoy \(response.name) has invalid date format: \(response.dataDateTime ?? "nil")")
        }
        
        // Get wave height with fallback to 0, handle invalid values
        let waveHeight = response.WaveHeight ?? 0.0
        let wavePeriod = response.WavePeriod ?? 0.0
        let maxHeight = response.MaxHeight ?? 0.0
        let maxPeriod = response.MaxPeriod ?? 0.0
        
        // Validate numeric values
        let validWaveHeight = DataFormatter.validateNumericValue(waveHeight)
        let validWavePeriod = DataFormatter.validateNumericValue(wavePeriod)
        let validMaxHeight = DataFormatter.validateNumericValue(maxHeight)
        let validMaxPeriod = DataFormatter.validateNumericValue(maxPeriod)
        
        let latitude = locationData.map { String(format: "%.2f", $0.latitude) } ?? "N/A"
        let longitude = locationData.map { String(format: "%.2f", $0.longitude) } ?? "N/A"
        
        // Handle other numeric fields with validation
        let windSpeed = response.WindSpeed ?? 0.0
        let seaTemp = response.SeaTemperature ?? 0.0
        let airTemp = response.AirTemperature ?? 0.0
        
        let validWindSpeed = DataFormatter.validateNumericValue(windSpeed)
        let validSeaTemp = DataFormatter.validateNumericValue(seaTemp)
        let validAirTemp = DataFormatter.validateNumericValue(airTemp)
        
        // Handle direction fields (should be 0-360 for degrees)
        let meanWaveDirection = response.MeanWaveDirection ?? 0
        let windDirection = response.WindDirection ?? 0
        
        let validWaveDirection = DataFormatter.validateDirection(meanWaveDirection)
        let validWindDirection = DataFormatter.validateDirection(windDirection)
        
        let buoy = Buoy(
            id: response.name,
            name: response.name,
            stationId: response.name,
            organization: organization,
            latitude: latitude,
            longitude: longitude,
            lastUpdated: lastUpdated,
            waveHeight: String(format: "%.1f", validWaveHeight),
            wavePeriod: String(format: "%.1f", validWavePeriod),
            waveDirection: String(validWaveDirection),
            windSpeed: String(format: "%.1f", validWindSpeed),
            waterTemp: String(format: "%.1f", validSeaTemp),
            airTemp: String(format: "%.1f", validAirTemp),
            distanceToShore: "N/A",
            depth: "N/A",
            maxWaveHeight: validMaxHeight,
            historicalData: historicalData,
            maxPeriod: String(format: "%.1f", validMaxPeriod)
        )
        
        print("Debug: Successfully created Buoy object for '\(response.name)' with organization '\(organization)'")
        return buoy
    }
    
    /// Format historical data from BuoyResponse array
    /// - Parameter data: Array of BuoyResponse objects
    /// - Returns: Array of WaveDataPoint objects
    func formatHistoricalData(_ data: [BuoyResponse]) -> [WaveDataPoint] {
        // Sort data by datetime
        let sortedData = data.sorted {
            (($0.dataDateTime ?? "") < ($1.dataDateTime ?? ""))
        }
        
        // Convert directly to WaveDataPoint format with error handling
        return sortedData.compactMap { response in
            let dateFormatter = ISO8601DateFormatter()
            let date: Date
            
            if let dataDateTime = response.dataDateTime,
               let parsedDate = dateFormatter.date(from: dataDateTime) {
                date = parsedDate
            } else {
                // Skip entries with invalid dates
                print("Warning: Skipping historical data entry with invalid date: \(response.dataDateTime ?? "nil")")
                return nil
            }
            
            // Validate wave height data
            let waveHeight = response.WaveHeight ?? 0.0
            let validWaveHeight = DataFormatter.validateNumericValue(waveHeight)
            
            return WaveDataPoint(
                time: date,
                waveHeight: validWaveHeight
            )
        }
    }
}

