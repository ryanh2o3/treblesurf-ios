// SpotsViewModel.swift
import Foundation
import SwiftUI

@MainActor
class SpotsViewModel: BaseViewModel {
    @Published var spots: [SpotData] = []
    @Published var isRefreshing: Bool = false
    
    private var dataStore: DataStore = DataStore()

    func setDataStore(_ store: DataStore) {
        dataStore = store
    }
    
    func loadSpots() async {
        logger.info("Loading spots for region: Donegal", category: .api)
        
        executeTask(context: "Load spots") {
            let spots = try await withCheckedThrowingContinuation { continuation in
                self.dataStore.fetchRegionSpots(region: "Donegal") { result in
                    continuation.resume(with: result)
                }
            }
            
            self.spots = spots
            self.logger.info("Loaded \(spots.count) spots", category: .general)
        }
    }
    
    // Helper method to get sorted spot names
    var spotNames: [String] {
        return spots.map { $0.name }.sorted()
    }
    
    // Refresh spots data by clearing cache and reloading
    func refreshSpots() async {
        logger.info("Refreshing spots data", category: .general)
        isRefreshing = true
        clearError()
        
        // Clear the region spots cache and refresh data
        dataStore.refreshRegionData(for: "Donegal")
        
        // Reload spots
        await loadSpots()
        
        isRefreshing = false
        logger.info("Spots refresh complete", category: .general)
    }
    
    // Refresh individual spot data
    func refreshSpotData(for spotId: String) async {
        logger.info("Refreshing spot data for: \(spotId)", category: .general)
        isRefreshing = true
        
        // Clear the specific spot's cache and refresh data
        dataStore.refreshSpotData(for: spotId)
        
        // Small delay to show refresh state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isRefreshing = false
        logger.debug("Spot data refreshed for: \(spotId)", category: .general)
    }
    
    // Refresh surf reports for all spots
    func refreshSurfReports() async {
        logger.info("Refreshing surf reports for all spots", category: .general)
        isRefreshing = true
        
        // Refresh surf reports for each spot
        for spot in spots {
            await refreshSpotSurfReports(for: spot)
        }
        
        isRefreshing = false
        logger.info("Surf reports refresh complete for all spots", category: .general)
    }
    
    // Refresh surf reports for a specific spot
    func refreshSpotSurfReports(for spot: SpotData) async {
        let spotId = "\(spot.countryRegionSpot.replacingOccurrences(of: "/", with: "#"))"
        
        // Convert spot data to country/region/spot format
        let components = spot.countryRegionSpot.split(separator: "/")
        guard components.count >= 3 else {
            logger.warning("Invalid spot format: \(spot.countryRegionSpot)", category: .dataProcessing)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spotName = String(components[2])
        
        logger.debug("Refreshing surf reports for spot: \(spotName)", category: .api)
        
        // Fetch fresh surf reports for this spot
        await withCheckedContinuation { continuation in
            APIClient.shared.fetchSurfReports(country: country, region: region, spot: spotName) { result in
                switch result {
                case .success:
                    self.logger.debug("Successfully refreshed reports for \(spotName)", category: .api)
                case .failure(let error):
                    self.logger.error("Failed to refresh reports for \(spotName): \(error.localizedDescription)", category: .api)
                }
                continuation.resume()
            }
        }
        
        // Force refresh the current conditions for this spot to ensure all data is fresh
        dataStore.fetchConditions(for: spotId) { _ in }
        
        // Small delay to ensure the refresh state is visible
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
