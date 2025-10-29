//
//  BuoysViewModel.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 03/05/2025.
//

import Foundation
import Combine

@MainActor
class BuoysViewModel: BaseViewModel {
    @Published var buoys: [Buoy] = []
    @Published var selectedFilter: String? = nil
    @Published var filteredBuoys: [Buoy] = []
    @Published var isRefreshing: Bool = false
    
    private var loadedHistoricalDataBuoyIds = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Shared Buoy Cache
    private let buoyCacheService = BuoyCacheService.shared
    private let weatherBuoyService: WeatherBuoyService
    
    init(weatherBuoyService: WeatherBuoyService = WeatherBuoyService.shared,
         errorHandler: ErrorHandlerProtocol? = nil,
         logger: ErrorLoggerProtocol? = nil) {
        self.weatherBuoyService = weatherBuoyService
        super.init(errorHandler: errorHandler, logger: logger)
        setupFilterSubscription()
    }
    
    private func setupFilterSubscription() {
        $selectedFilter
            .sink { [weak self] filter in
                guard let self = self else { return }
                self.filterBuoys(by: filter)
            }
            .store(in: &cancellables)
    }
    
    private func filterBuoys(by organization: String?) {
        if let organization = organization {
            if organization == "Nearby" {
                // In a real app, would filter by distance to user
                filteredBuoys = buoys.prefix(3).map { $0 }
            } else {
                filteredBuoys = buoys.filter { $0.organization == organization }
            }
        } else {
            filteredBuoys = buoys
        }
    }
    
    @MainActor
    func loadBuoys() async {
        logger.log("Loading buoys from NorthAtlantic region", level: .info, category: .api)
        
        var buoyNames = ["M4", "M6"]
        var buoyLocations: [BuoyLocation] = []
        loadedHistoricalDataBuoyIds.removeAll()
        
        do {
            // Fetch buoy locations
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoys(region: "NorthAtlantic") { result in
                    continuation.resume(with: result)
                }
            }
            
            buoyNames = buoyResponses.map { $0.name }
            buoyLocations = buoyResponses
            
            logger.log("Fetched \(buoyNames.count) buoy locations", level: .debug, category: .api)
            
            let spacedNames = buoyNames.filter { $0.contains(" ") }
            if !spacedNames.isEmpty {
                logger.log("Buoy names with spaces: \(spacedNames)", level: .debug, category: .dataProcessing)
            }
        } catch {
            logger.log("Error fetching buoy locations: \(error.localizedDescription)", level: .error, category: .api)
            // Continue with default buoy names if location fetch fails
        }
        
        do {
            // Fetch current buoy data
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoyData(buoyNames: buoyNames) { result in
                    continuation.resume(with: result)
                }
            }
            
            logger.log("API returned \(buoyResponses.count) buoy responses", level: .debug, category: .api)
            
            let returnedNames = buoyResponses.map { $0.name }
            let missingBuoys = Set(buoyNames).subtracting(Set(returnedNames))
            if !missingBuoys.isEmpty {
                logger.log("Missing buoy data for: \(Array(missingBuoys))", level: .warning, category: .api)
            }
            
            // Convert responses to buoys
            let buoys = buoyResponses.compactMap { response in
                logger.log("Processing buoy: \(response.name)", level: .debug, category: .dataProcessing)
                let locationData = buoyLocations.first { $0.name == response.name }
                let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
                if convertedBuoy == nil {
                    logger.log("Failed to convert buoy: \(response.name)", level: .warning, category: .dataProcessing)
                }
                return convertedBuoy
            }
            
            if buoys.isEmpty {
                logger.log("No valid buoy data could be processed", level: .warning, category: .dataProcessing)
            } else {
                logger.log("Successfully processed \(buoys.count) of \(buoyResponses.count) buoys", level: .info, category: .general)
            }
            
            self.buoys = buoys
            filterBuoys(by: selectedFilter)
            
        } catch {
            logger.log("Error fetching buoy data", level: .error, category: .api)
            
            // Log detailed error information for decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    logger.log("Type mismatch: Expected \(type) at \(context.codingPath)", level: .error, category: .dataProcessing)
                case .keyNotFound(let key, let context):
                    logger.log("Key not found: \(key) at \(context.codingPath)", level: .error, category: .dataProcessing)
                case .valueNotFound(let type, let context):
                    logger.log("Value not found: \(type) at \(context.codingPath)", level: .error, category: .dataProcessing)
                case .dataCorrupted(let context):
                    logger.log("Data corrupted: \(context)", level: .error, category: .dataProcessing)
                @unknown default:
                    logger.log("Unknown decoding error: \(decodingError)", level: .error, category: .dataProcessing)
                }
            }
            
            // Continue with empty buoys array
            self.buoys = []
            filterBuoys(by: selectedFilter)
            
            // Show error to user
            handleError(error, context: "Load buoys")
        }
    }
    
    @MainActor
    func loadHistoricalDataForBuoy(id: String, updateSelectedBuoy: @escaping (Buoy?) -> Void) async {
        // Skip if already loaded
        if loadedHistoricalDataBuoyIds.contains(id) {
            logger.log("Historical data already loaded for buoy: \(id)", level: .debug, category: .cache)
            return
        }
        
        logger.log("Loading historical data for buoy: \(id)", level: .info, category: .api)
        
        do {
            let historicalData = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchLast24HoursBuoyData(buoyName: id) { result in
                    continuation.resume(with: result)
                }
            }
            
            // Find the buoy to update
            if let index = buoys.firstIndex(where: { $0.id == id }) {
                // Format the historical data
                let formattedData = formatHistoricalData(historicalData)
                
                // Create a new array to force SwiftUI to detect the change
                var updatedBuoys = self.buoys
                updatedBuoys[index].historicalData = formattedData
                self.buoys = updatedBuoys
                
                // Mark as loaded
                loadedHistoricalDataBuoyIds.insert(id)
                
                // Update filtered buoys
                filterBuoys(by: selectedFilter)
                
                updateSelectedBuoy(updatedBuoys[index])
                
                logger.log("Historical data loaded for buoy \(id): \(formattedData.count) data points", level: .info, category: .general)
            } else {
                logger.log("Buoy not found: \(id)", level: .warning, category: .general)
            }
        } catch {
            logger.log("Error fetching historical data for buoy \(id)", level: .error, category: .api)
            handleError(error, context: "Load historical buoy data")
        }
    }
    
    // Refresh buoys data by clearing cache and reloading
    @MainActor
    func refreshBuoys() async {
        logger.log("Refreshing buoys data", level: .info, category: .general)
        isRefreshing = true
        
        // Clear all cached data to force complete refresh
        loadedHistoricalDataBuoyIds.removeAll()
        buoys.removeAll()
        filteredBuoys.removeAll()
        clearError()
        
        // Reload buoys data fresh from API
        await loadBuoys()
        
        isRefreshing = false
        logger.log("Buoys refresh complete", level: .info, category: .general)
    }
    
    private func updateBuoysFromCache() {
        // Update buoys when cache changes
        Task { @MainActor in
            let buoyNames = buoys.map { $0.id }
            if let cachedData = buoyCacheService.getCachedBuoyData(for: buoyNames) {
                let buoyLocations = buoys.compactMap { buoy in
                    // Create a simple BuoyLocation from existing buoy data
                    BuoyLocation(
                        region_buoy: buoy.organization,
                        latitude: Double(buoy.latitude) ?? 0.0,
                        longitude: Double(buoy.longitude) ?? 0.0,
                        name: buoy.name
                    )
                }
                await createBuoysFromResponses(cachedData, buoyLocations: buoyLocations)
            }
        }
    }
    
    private func createBuoysFromResponses(_ responses: [BuoyResponse], buoyLocations: [BuoyLocation]) async {
        logger.log("Creating buoys from \(responses.count) responses", level: .debug, category: .dataProcessing)
        
        let buoys = responses.compactMap { response in
            logger.log("Processing buoy: \(response.name)", level: .debug, category: .dataProcessing)
            let locationData = buoyLocations.first { $0.name == response.name }
            let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
            if convertedBuoy == nil {
                logger.log("Failed to convert buoy: \(response.name)", level: .warning, category: .dataProcessing)
            }
            return convertedBuoy
        }
        
        await MainActor.run {
            self.buoys = buoys
            self.filterBuoys(by: self.selectedFilter)
            self.logger.log("Created \(buoys.count) buoys from cache", level: .info, category: .cache)
        }
    }
    
    private func formatHistoricalData(_ data: [BuoyResponse]) -> [WaveDataPoint] {
        return weatherBuoyService.formatHistoricalData(data)
    }
}


// Models
struct Buoy: Identifiable {
    let id: String
    let name: String
    let stationId: String
    let organization: String
    let latitude: String
    let longitude: String
    let lastUpdated: String
    let waveHeight: String
    let wavePeriod: String
    let waveDirection: String
    let windSpeed: String
    let waterTemp: String
    let airTemp: String
    let distanceToShore: String
    let depth: String
    let maxWaveHeight: Double
    var historicalData: [WaveDataPoint]
    let maxPeriod: String
}

struct WaveDataPoint: Identifiable {
    let id = UUID()
    let time: Date
    let waveHeight: Double
}

struct HistoricalDataPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let waveHeight: Double
    let wavePeriod: Double
    let waveDirection: Int
    let windSpeed: Double
    let windDirection: Int
}
