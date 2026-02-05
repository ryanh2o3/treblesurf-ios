// SpotsViewModel.swift
import Foundation
import SwiftUI

@MainActor
class SpotsViewModel: BaseViewModel {
    @Published var spots: [SpotData] = []
    @Published var isRefreshing: Bool = false
    
    private var dataStore: DataStore
    private let apiClient: APIClientProtocol
    
    init(
        dataStore: DataStore,
        apiClient: APIClientProtocol,
        errorHandler: ErrorHandlerProtocol? = nil,
        logger: ErrorLoggerProtocol? = nil
    ) {
        self.dataStore = dataStore
        self.apiClient = apiClient
        super.init(errorHandler: errorHandler, logger: logger)
    }

    func setDataStore(_ store: DataStore) {
        dataStore = store
    }
    
    func loadSpots() async {
        logger.log("Loading spots for region: Donegal", level: .info, category: .api)
        
        await executeTask(context: "Load spots") {
            let spots = try await self.dataStore.fetchRegionSpots(region: "Donegal")
            self.spots = spots
            self.logger.log("Loaded \(spots.count) spots", level: .info, category: .general)
        }
    }
    
    // Helper method to get sorted spot names
    var spotNames: [String] {
        return spots.map { $0.name }.sorted()
    }
    
    // Refresh spots data by clearing cache and reloading
    func refreshSpots() async {
        logger.log("Refreshing spots data", level: .info, category: .general)
        isRefreshing = true
        clearError()
        
        // Clear the region spots cache and refresh data
        dataStore.refreshRegionData(for: "Donegal")
        
        // Reload spots
        await loadSpots()
        
        isRefreshing = false
        logger.log("Spots refresh complete", level: .info, category: .general)
    }
    
    // Refresh individual spot data
    func refreshSpotData(for spotId: String) async {
        logger.log("Refreshing spot data for: \(spotId)", level: .info, category: .general)
        isRefreshing = true
        
        // Clear the specific spot's cache and refresh data
        dataStore.refreshSpotData(for: spotId)
        
        // Small delay to show refresh state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isRefreshing = false
        logger.log("Spot data refreshed for: \(spotId)", level: .debug, category: .general)
    }
    
    // Refresh surf reports for all spots
    func refreshSurfReports() async {
        logger.log("Refreshing surf reports for all spots", level: .info, category: .general)
        isRefreshing = true
        
        // Refresh surf reports for each spot
        for spot in spots {
            await refreshSpotSurfReports(for: spot)
        }
        
        isRefreshing = false
        logger.log("Surf reports refresh complete for all spots", level: .info, category: .general)
    }
    
    // Refresh surf reports for a specific spot
    func refreshSpotSurfReports(for spot: SpotData) async {
        let spotId = "\(spot.countryRegionSpot.replacingOccurrences(of: "/", with: "#"))"
        
        // Convert spot data to country/region/spot format
        let components = spot.countryRegionSpot.split(separator: "/")
        guard components.count >= 3 else {
            logger.log("Invalid spot format: \(spot.countryRegionSpot)", level: .warning, category: .dataProcessing)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spotName = String(components[2])
        
        logger.log("Refreshing surf reports for spot: \(spotName)", level: .debug, category: .api)
        
        // Fetch fresh surf reports for this spot
        do {
            _ = try await apiClient.fetchSurfReports(country: country, region: region, spot: spotName)
            self.logger.log("Successfully refreshed reports for \(spotName)", level: .debug, category: .api)
        } catch {
            self.logger.log("Failed to refresh reports for \(spotName): \(error.localizedDescription)", level: .error, category: .api)
        }
        
        // Force refresh the current conditions for this spot to ensure all data is fresh
        _ = await dataStore.fetchConditions(for: spotId)
        
        // Small delay to ensure the refresh state is visible
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
