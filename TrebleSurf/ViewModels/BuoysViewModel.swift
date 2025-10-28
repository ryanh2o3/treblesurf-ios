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
        logger.info("Loading buoys from NorthAtlantic region", category: .api)
        
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
            
            logger.debug("Fetched \(buoyNames.count) buoy locations", category: .api)
            
            let spacedNames = buoyNames.filter { $0.contains(" ") }
            if !spacedNames.isEmpty {
                logger.debug("Buoy names with spaces: \(spacedNames)", category: .dataProcessing)
            }
        } catch {
            logger.error("Error fetching buoy locations: \(error.localizedDescription)", category: .api)
            // Continue with default buoy names if location fetch fails
        }
        
        do {
            // Fetch current buoy data
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoyData(buoyNames: buoyNames) { result in
                    continuation.resume(with: result)
                }
            }
            
            logger.debug("API returned \(buoyResponses.count) buoy responses", category: .api)
            
            let returnedNames = buoyResponses.map { $0.name }
            let missingBuoys = Set(buoyNames).subtracting(Set(returnedNames))
            if !missingBuoys.isEmpty {
                logger.warning("Missing buoy data for: \(Array(missingBuoys))", category: .api)
            }
            
            // Convert responses to buoys
            let buoys = buoyResponses.compactMap { response in
                logger.debug("Processing buoy: \(response.name)", category: .dataProcessing)
                let locationData = buoyLocations.first { $0.name == response.name }
                let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
                if convertedBuoy == nil {
                    logger.warning("Failed to convert buoy: \(response.name)", category: .dataProcessing)
                }
                return convertedBuoy
            }
            
            if buoys.isEmpty {
                logger.warning("No valid buoy data could be processed", category: .dataProcessing)
            } else {
                logger.info("Successfully processed \(buoys.count) of \(buoyResponses.count) buoys", category: .general)
            }
            
            self.buoys = buoys
            filterBuoys(by: selectedFilter)
            
        } catch {
            logger.error("Error fetching buoy data", category: .api)
            
            // Log detailed error information for decoding errors
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    logger.error("Type mismatch: Expected \(type) at \(context.codingPath)", category: .dataProcessing)
                case .keyNotFound(let key, let context):
                    logger.error("Key not found: \(key) at \(context.codingPath)", category: .dataProcessing)
                case .valueNotFound(let type, let context):
                    logger.error("Value not found: \(type) at \(context.codingPath)", category: .dataProcessing)
                case .dataCorrupted(let context):
                    logger.error("Data corrupted: \(context)", category: .dataProcessing)
                @unknown default:
                    logger.error("Unknown decoding error: \(decodingError)", category: .dataProcessing)
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
            logger.debug("Historical data already loaded for buoy: \(id)", category: .cache)
            return
        }
        
        logger.info("Loading historical data for buoy: \(id)", category: .api)
        
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
                
                logger.info("Historical data loaded for buoy \(id): \(formattedData.count) data points", category: .general)
            } else {
                logger.warning("Buoy not found: \(id)", category: .general)
            }
        } catch {
            logger.error("Error fetching historical data for buoy \(id)", category: .api)
            handleError(error, context: "Load historical buoy data")
        }
    }
    
    // Refresh buoys data by clearing cache and reloading
    @MainActor
    func refreshBuoys() async {
        logger.info("Refreshing buoys data", category: .general)
        isRefreshing = true
        
        // Clear all cached data to force complete refresh
        loadedHistoricalDataBuoyIds.removeAll()
        buoys.removeAll()
        filteredBuoys.removeAll()
        clearError()
        
        // Reload buoys data fresh from API
        await loadBuoys()
        
        isRefreshing = false
        logger.info("Buoys refresh complete", category: .general)
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
        logger.debug("Creating buoys from \(responses.count) responses", category: .dataProcessing)
        
        let buoys = responses.compactMap { response in
            logger.debug("Processing buoy: \(response.name)", category: .dataProcessing)
            let locationData = buoyLocations.first { $0.name == response.name }
            let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
            if convertedBuoy == nil {
                logger.warning("Failed to convert buoy: \(response.name)", category: .dataProcessing)
            }
            return convertedBuoy
        }
        
        await MainActor.run {
            self.buoys = buoys
            self.filterBuoys(by: self.selectedFilter)
            self.logger.info("Created \(buoys.count) buoys from cache", category: .cache)
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
