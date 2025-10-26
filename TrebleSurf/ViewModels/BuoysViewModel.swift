//
//  BuoysViewModel.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 03/05/2025.
//

import Foundation
import Combine

@MainActor
class BuoysViewModel: ObservableObject {
    @Published var buoys: [Buoy] = []
    @Published var selectedFilter: String? = nil
    @Published var filteredBuoys: [Buoy] = []
    @Published var isRefreshing: Bool = false
    
    private var loadedHistoricalDataBuoyIds = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Shared Buoy Cache
    private let buoyCacheService = BuoyCacheService.shared
    private let weatherBuoyService: WeatherBuoyService
    
    init(weatherBuoyService: WeatherBuoyService = WeatherBuoyService.shared) {
        self.weatherBuoyService = weatherBuoyService
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
        var buoyNames = ["M4", "M6"]
        var buoyLocations: [BuoyLocation] = []
        loadedHistoricalDataBuoyIds.removeAll()
        
        do {
            // Only fetch current buoy data
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoys(region: "NorthAtlantic") { result in
                    continuation.resume(with: result)
                }
            }
            
            buoyNames = buoyResponses.map { response in
                response.name
            }
            buoyLocations = buoyResponses
            
            print("Debug: Fetched buoy names: \(buoyNames)")
            print("Debug: Buoy names with spaces: \(buoyNames.filter { $0.contains(" ") })")
        } catch {
            print("Error fetching buoy locations: \(error)")
            // Continue with default buoy names if location fetch fails
        }
        
        do {
            // Only fetch current buoy data
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoyData(buoyNames: buoyNames) { result in
                    continuation.resume(with: result)
                }
            }
            
            // Create buoys with empty historical data, filtering out any that fail to convert
            print("Debug: Requested buoy names: \(buoyNames)")
            print("Debug: API returned \(buoyResponses.count) buoy responses")
            let returnedNames = buoyResponses.map { $0.name }
            print("Debug: Returned buoy names: \(returnedNames)")
            
            let missingBuoys = Set(buoyNames).subtracting(Set(returnedNames))
            if !missingBuoys.isEmpty {
                print("Warning: Missing buoy data for: \(Array(missingBuoys))")
            }
            
            let buoys = buoyResponses.compactMap { response in
                print("Debug: Processing buoy response with name: '\(response.name)'")
                let locationData = buoyLocations.first { $0.name == response.name }
                let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
                if convertedBuoy == nil {
                    print("Debug: Failed to convert buoy '\(response.name)' - convertToBuoy returned nil")
                } else {
                    print("Debug: Successfully converted buoy '\(response.name)'")
                }
                return convertedBuoy
            }
            
            if buoys.isEmpty {
                print("Warning: No valid buoy data could be processed")
            } else {
                print("Successfully processed \(buoys.count) out of \(buoyResponses.count) buoy responses")
            }
            
            self.buoys = buoys
            filterBuoys(by: selectedFilter)
            
        } catch {
            print("Error fetching buoy data: \(error)")
            
            // Provide more detailed error information
            if let decodingError = error as? DecodingError {
                switch decodingError {
                case .typeMismatch(let type, let context):
                    print("Type mismatch error: Expected \(type) but found different type at \(context.codingPath)")
                    print("Debug description: \(context.debugDescription)")
                case .keyNotFound(let key, let context):
                    print("Key not found: \(key) at \(context.codingPath)")
                case .valueNotFound(let type, let context):
                    print("Value not found: Expected \(type) at \(context.codingPath)")
                case .dataCorrupted(let context):
                    print("Data corrupted: \(context)")
                @unknown default:
                    print("Unknown decoding error: \(decodingError)")
                }
            }
            
            // Continue with empty buoys array instead of crashing
            self.buoys = []
            filterBuoys(by: selectedFilter)
        }
    }
    
    @MainActor
    func loadHistoricalDataForBuoy(id: String, updateSelectedBuoy: @escaping (Buoy?) -> Void) async {
        // Skip if already loaded
        if loadedHistoricalDataBuoyIds.contains(id) {
            return
        }
        
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
                
            }
        } catch {
            print("Error fetching historical data for buoy \(id): \(error)")
        }
    }
    
    // Refresh buoys data by clearing cache and reloading
    @MainActor
    func refreshBuoys() async {
        isRefreshing = true
        
        // Clear all cached data to force complete refresh
        loadedHistoricalDataBuoyIds.removeAll()
        buoys.removeAll()
        filteredBuoys.removeAll()
        
        // Reload buoys data fresh from API
        await loadBuoys()
        
        isRefreshing = false
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
        // Create buoys with empty historical data, filtering out any that fail to convert
        print("Debug: Requested buoy names: \(responses.map { $0.name })")
        print("Debug: API returned \(responses.count) buoy responses")
        let returnedNames = responses.map { $0.name }
        print("Debug: Returned buoy names: \(returnedNames)")
        
        let buoys = responses.compactMap { response in
            print("Debug: Processing buoy response with name: '\(response.name)'")
            let locationData = buoyLocations.first { $0.name == response.name }
            let convertedBuoy = self.weatherBuoyService.convertToBuoy(response: response, historicalData: [], locationData: locationData)
            if convertedBuoy == nil {
                print("Debug: Failed to convert buoy '\(response.name)' - convertToBuoy returned nil")
            } else {
                print("Debug: Successfully converted buoy '\(response.name)'")
            }
            return convertedBuoy
        }
        
        await MainActor.run {
            self.buoys = buoys
            self.filterBuoys(by: self.selectedFilter)
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
