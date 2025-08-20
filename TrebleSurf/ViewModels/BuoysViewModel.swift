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
    
    private var loadedHistoricalDataBuoyIds = Set<String>()
    
    private var cancellables = Set<AnyCancellable>()
    
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
        } catch {
            print("Error fetching buoy data: \(error)")
        }
        
            do {
                // Only fetch current buoy data
                let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                    APIClient.shared.fetchBuoyData(buoyNames: buoyNames) { result in
                        continuation.resume(with: result)
                    }
                }
                
                // Create buoys with empty historical data
                let buoys = buoyResponses.map { response in
                    let locationData = buoyLocations.first { $0.name == response.name }
                    return convertToBuoy(response: response, historicalData: [], locationData: locationData)
                }
                
                self.buoys = buoys
                filterBuoys(by: selectedFilter)
            } catch {
                print("Error fetching buoy data: \(error)")
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
    }

private func convertToBuoy(response: BuoyResponse, historicalData: [WaveDataPoint], locationData: BuoyLocation?) -> Buoy {
    // Extract region from region_buoy
    let regionParts = response.region_buoy.split(separator: "_")
    let organization = regionParts.first.map(String.init) ?? "Unknown"
    
    // Format the timestamp
    let dateFormatter = ISO8601DateFormatter()
    let date = response.dataDateTime.flatMap { dateFormatter.date(from: $0) } ?? Date()
    let minutesAgo = Int(Date().timeIntervalSince(date) / 60)
    let lastUpdated = "\(minutesAgo) minutes ago"
    
    // Get wave height with fallback to 0
    let waveHeight = response.WaveHeight ?? 0.0
        
    let latitude = locationData.map { String(format: "%.2f", $0.latitude) } ?? "N/A"
    let longitude = locationData.map { String(format: "%.2f", $0.longitude) } ?? "N/A"
        
    return Buoy(
        id: response.name,
        name: response.name,
        stationId: response.name,
        organization: organization,
        latitude: latitude,
        longitude: longitude,
        lastUpdated: lastUpdated,
        waveHeight: String(format: "%.1f", waveHeight),
        wavePeriod: String(format: "%.1f", response.WavePeriod ?? 0),
        waveDirection: String(response.MeanWaveDirection ?? 0),
        windSpeed: String(format: "%.1f", response.WindSpeed ?? 0),
        waterTemp: String(format: "%.1f", response.SeaTemperature ?? 0),
        airTemp: String(format: "%.1f", response.AirTemperature ?? 0),
        distanceToShore: "N/A",
        depth: "N/A",
        maxWaveHeight: response.MaxHeight ?? 0.0,
        historicalData: historicalData,
        maxPeriod: String(format: "%.1f", response.MaxPeriod ?? 0)
    )
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
        
        // Convert directly to WaveDataPoint format
        return sortedData.map { response in
            let dateFormatter = ISO8601DateFormatter()
            let date = response.dataDateTime.flatMap { dateFormatter.date(from: $0) } ?? Date()
            
            return WaveDataPoint(
                time: date,
                waveHeight: response.WaveHeight ?? 0.0
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
