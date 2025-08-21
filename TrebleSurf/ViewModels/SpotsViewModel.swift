// SpotsViewModel.swift
import Foundation
import SwiftUI

@MainActor
class SpotsViewModel: ObservableObject {
    @Published var spots: [SpotData] = []
    @Published var isLoading: Bool = false
    @Published var isRefreshing: Bool = false
    @Published var errorMessage: String?
    
    private var dataStore: DataStore = DataStore()

    func setDataStore(_ store: DataStore) {
            dataStore = store
        }
    
    func loadSpots() async {
        isLoading = true
        errorMessage = nil
        
        do {
            try await withCheckedThrowingContinuation { continuation in
                dataStore.fetchRegionSpots(region: "Donegal") { [weak self] result in
                    switch result {
                    case .success(let spots):
                        Task { @MainActor in
                            self?.spots = spots
                            self?.isLoading = false
                        }
                        continuation.resume()
                    case .failure(let error):
                        Task { @MainActor in
                            self?.errorMessage = error.localizedDescription
                            self?.isLoading = false
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            // Error already handled in the continuation
        }
    }
    
    // Helper method to get sorted spot names
    var spotNames: [String] {
        return spots.map { $0.name }.sorted()
    }
    
    // Refresh spots data by clearing cache and reloading
    func refreshSpots() async {
        isRefreshing = true
        
        // Clear the region spots cache and refresh data
        dataStore.refreshRegionData(for: "Donegal")
        
        // Reload spots
        await loadSpots()
        
        isRefreshing = false
    }
    
    // Refresh individual spot data
    func refreshSpotData(for spotId: String) async {
        isRefreshing = true
        
        // Clear the specific spot's cache and refresh data
        dataStore.refreshSpotData(for: spotId)
        
        // Small delay to show refresh state
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
        
        isRefreshing = false
    }
    
    // Refresh surf reports for all spots
    func refreshSurfReports() async {
        isRefreshing = true
        
        // Refresh surf reports for each spot
        for spot in spots {
            await refreshSpotSurfReports(for: spot)
        }
        
        isRefreshing = false
    }
    
    // Refresh surf reports for a specific spot
    func refreshSpotSurfReports(for spot: SpotData) async {
        let spotId = "\(spot.countryRegionSpot.replacingOccurrences(of: "/", with: "#"))"
        
        // Convert spot data to country/region/spot format
        let components = spot.countryRegionSpot.split(separator: "/")
        guard components.count >= 3 else { return }
        
        let country = String(components[0])
        let region = String(components[1])
        let spotName = String(components[2])
        
        // Fetch fresh surf reports for this spot
        await withCheckedContinuation { continuation in
            APIClient.shared.fetchSurfReports(country: country, region: region, spot: spotName) { result in
                // The LiveSpotViewModel will handle the actual display of surf reports
                // This just ensures fresh data is fetched
                continuation.resume()
            }
        }
        
        // Force refresh the current conditions for this spot to ensure all data is fresh
        dataStore.fetchConditions(for: spotId) { _ in }
        
        // Small delay to ensure the refresh state is visible
        try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
    }
}
