//
//  BuoysViewModel.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 03/05/2025.
//

import Foundation
import Combine

class BuoysViewModel: ObservableObject {
    @Published var buoys: [Buoy] = []
    @Published var selectedFilter: String? = nil
    @Published var filteredBuoys: [Buoy] = []
    @Published var isRefreshing: Bool = false
    
    private var loadedHistoricalDataBuoyIds = Set<String>()
    private var cancellables = Set<AnyCancellable>()
    
    // MARK: - Shared Buoy Cache
    private let buoyCacheService = BuoyCacheService.shared
    
    init() {
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
                let convertedBuoy = convertToBuoy(response: response, historicalData: [], locationData: locationData)
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
            let convertedBuoy = convertToBuoy(response: response, historicalData: [], locationData: locationData)
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
}

private func convertToBuoy(response: BuoyResponse, historicalData: [WaveDataPoint], locationData: BuoyLocation?) -> Buoy? {
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
    
    // Validate numeric values and provide fallbacks for invalid data
    let validWaveHeight = waveHeight.isFinite && waveHeight >= 0 ? waveHeight : 0.0
    let validWavePeriod = wavePeriod.isFinite && wavePeriod >= 0 ? wavePeriod : 0.0
    let validMaxHeight = maxHeight.isFinite && maxHeight >= 0 ? maxHeight : 0.0
    let validMaxPeriod = maxPeriod.isFinite && maxPeriod >= 0 ? maxPeriod : 0.0
    
    let latitude = locationData.map { String(format: "%.2f", $0.latitude) } ?? "N/A"
    let longitude = locationData.map { String(format: "%.2f", $0.longitude) } ?? "N/A"
    
    // Handle other numeric fields with validation
    let windSpeed = response.WindSpeed ?? 0.0
    let seaTemp = response.SeaTemperature ?? 0.0
    let airTemp = response.AirTemperature ?? 0.0
    
    let validWindSpeed = windSpeed.isFinite ? windSpeed : 0.0
    let validSeaTemp = seaTemp.isFinite ? seaTemp : 0.0
    let validAirTemp = airTemp.isFinite ? airTemp : 0.0
    
    // Handle direction fields (should be 0-360 for degrees)
    let meanWaveDirection = response.MeanWaveDirection ?? 0
    let windDirection = response.WindDirection ?? 0
    
    let validWaveDirection = (0...360).contains(meanWaveDirection) ? meanWaveDirection : 0
    let validWindDirection = (0...360).contains(windDirection) ? windDirection : 0
        
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
    
    private func generateHistoricalData(around baseHeight: Double) -> [WaveDataPoint] {
        let calendar = Calendar.current
        let now = Date()
        
        return (0..<24).map { hour in
            let time = calendar.date(byAdding: .hour, value: -hour, to: now)!
            let variation = Double.random(in: -1.0...1.5)
            let height = max(0.5, baseHeight + variation)
            return WaveDataPoint(time: time, waveHeight: height)
        }.reversed()
    }
    
    private func formatHistoricalData(_ data: [BuoyResponse]) -> [WaveDataPoint] {
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
            let validWaveHeight = waveHeight.isFinite && waveHeight >= 0 ? waveHeight : 0.0
            
            return WaveDataPoint(
                time: date,
                waveHeight: validWaveHeight
            )
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
