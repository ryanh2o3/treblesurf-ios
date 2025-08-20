//
//  DataStore.swift
//  TrebleSurf
//
//  Created by Ryan Patton on 11/05/2025.
//
import Foundation
import SwiftUI
class DataStore: ObservableObject {
    static let shared = DataStore()

    @Published var currentConditions = ConditionData(from: [:])
    // Cache for storing multiple spot conditions with timestamps
    private var spotConditionsCache: [String: (conditions: ConditionData, timestamp: Date)] = [:]
    
    @Published var regionSpots: [SpotData] = []
    private var regionSpotsCache: [String: (spots: [SpotData], timestamp: Date)] = [:]
    
    // Using only the flattened format
        @Published var currentForecastEntries: [ForecastEntry] = []
        private var spotForecastCache: [String: (forecast: [ForecastEntry], timestamp: Date)] = [:]
    
    // Current selected spot ID
    @Published var currentSpotId: String = ""
    
    // Cache expiration time (e.g., 30 minutes)
    private let cacheExpirationInterval: TimeInterval = 30 * 60
    private let spotCacheExpirationInterval: TimeInterval = 60 * 60 * 24 * 4
    // Fetch conditions for a spot
    func fetchConditions(for spotId: String, completion: @escaping (Bool) -> Void = {_ in}) {
        // Check if we have cached data that's still valid
        if let cached = spotConditionsCache[spotId],
           Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
            
            // Use cached data but ensure updates on main thread
            DispatchQueue.main.async {
                self.currentSpotId = spotId
                self.currentConditions = cached.conditions
                completion(true)
            }
            return
        }

        // Split the spotId into components
        let components = spotId.split(separator: "#")
        guard components.count == 3 else {
            print("Invalid spotId format")
            completion(false)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        // Make API call
        APIClient.shared.fetchCurrentConditions(country: country, region: region, spot: spot) { [weak self] (result: Result<[CurrentConditionsResponse], Error>) in
            guard let self = self else { return }
            
            switch result {
            case .success(let responses):
                if let firstResponse = responses.first {
                    // Update on main thread
                    DispatchQueue.main.async {
                        // Update current conditions
                        self.currentConditions = firstResponse.data
                        
                        // Update current spot ID
                        self.currentSpotId = spotId
                        
                        // Cache the data with current timestamp
                        self.spotConditionsCache[spotId] = (firstResponse.data, Date())
                        
                        completion(true)
                    }
                }
                
            case .failure(let error):
                print("Error fetching conditions: \(error)")
                completion(false)
            }
        }
    }
    
    func fetchForecast(for spotId: String, completion: @escaping (Bool) -> Void = {_ in}) {
            // Check if we have cached data that's still valid
            if let cached = spotForecastCache[spotId],
               Date().timeIntervalSince(cached.timestamp) < cacheExpirationInterval {
                
                // Use cached data but ensure updates on main thread
                DispatchQueue.main.async {
                    self.currentForecastEntries = cached.forecast
                    completion(true)
                }
                return
            }

            // Split the spotId into components
            let components = spotId.split(separator: "#")
            guard components.count == 3 else {
                print("Invalid spotId format")
                completion(false)
                return
            }
            
            let country = String(components[0])
            let region = String(components[1])
            let spot = String(components[2])
            
            // Make API call and convert response to ForecastEntry objects directly
            APIClient.shared.fetchForecast(country: country, region: region, spot: spot) { [weak self] (result: Result<[ForecastResponse], Error>) in
                guard let self = self else { return }
                
                switch result {
                case .success(let responses):
                    // Convert to ForecastEntry objects
                    let entries = responses.toForecastEntries()
                    
                    // Update on main thread
                    DispatchQueue.main.async {
                        // Update current forecast with flattened data
                        self.currentForecastEntries = entries
                        
                        // Cache the flattened data with current timestamp
                        self.spotForecastCache[spotId] = (entries, Date())
                        
                        completion(true)
                    }
                    
                case .failure(let error):
                    print("Error fetching forecast: \(error)")
                    completion(false)
                }
            }
        }
    
    func fetchRegionSpots(region: String, completion: @escaping (Result<[SpotData], Error>) -> Void) {
        // Check if we have cached data that's still valid
        if let cached = regionSpotsCache[region],
           Date().timeIntervalSince(cached.timestamp) < spotCacheExpirationInterval {
            
            // Use cached data
            DispatchQueue.main.async {
                completion(.success(cached.spots))
            }
            return
        }

        print("Fetching spots for region: \(region)")
        
        // For now we only handle Donegal, but this could be expanded
        APIClient.shared.fetchDonegalSpots { [weak self] result in
            guard let self = self else { return }
            print("result \(result)")
            switch result {
            case .success(let spots):
                print("Successfully fetched \(spots.count) spots for region: \(region)")
                // Cache the data with current timestamp
                self.regionSpotsCache[region] = (spots, Date())
                
                DispatchQueue.main.async {
                    // Update the published property
                    self.regionSpots = spots
                    completion(.success(spots))
                }
                
            case .failure(let error):
                print("Error fetching spots for region \(region): \(error)")
                print("Error details: \(error.localizedDescription)")
                completion(.failure(error))
            }
        }
    }
    
    func fetchSpotImage(for spotId: String, completion: @escaping (Image?) -> Void = {_ in}) {
        print("Fetching image for spotId: \(spotId)")
        // Check if we have cached data with image already
        for (_, cachedData) in regionSpotsCache {
            if let spotIndex = cachedData.spots.firstIndex(where: { $0.id == spotId }),
               let imageData = cachedData.spots[spotIndex].imageString,
               !imageData.isEmpty,
               Date().timeIntervalSince(cachedData.timestamp) < spotCacheExpirationInterval {
                print("Using cached image data for spotId: \(spotId)")
                print("Image data: \(imageData)")
                
                // Convert base64 to UIImage if we have it cached
                if let image = UIImage(data: Data(base64Encoded: imageData) ?? Data()) {
                    let swiftUIImage = Image(uiImage: image)
                                    DispatchQueue.main.async {
                                        completion(swiftUIImage)
                                    }
                    return
                }
            }
        }
        
        // Split the spotId into components
        let components = spotId.split(separator: "#")
        guard components.count == 3 else {
            print("Invalid spotId format")
            completion(nil)
            return
        }
        
        let country = String(components[0])
        let region = String(components[1])
        let spot = String(components[2])
        
        // Call locationInfo API route
        APIClient.shared.fetchLocationInfo(country: country, region: region, spot: spot) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let spotData):
                DispatchQueue.main.async {
                    // Update cache with the new image data
                    for (regionKey, cachedData) in self.regionSpotsCache {
                        var updatedSpots = cachedData.spots
                        if let index = updatedSpots.firstIndex(where: { $0.id == spotId }) {
                            // Create a mutable copy of the original spot
                            var updatedSpot = updatedSpots[index]
                            // Update the image property
                            updatedSpot.imageString = spotData.image
                            // Replace the spot in the array
                            updatedSpots[index] = updatedSpot
                            // Update the cache
                            self.regionSpotsCache[regionKey] = (updatedSpots, Date())
                        }
                    }
                    
                    // Convert base64 to UIImage
                    if let imageData = spotData.imageString,
                       let image = UIImage(data: Data(base64Encoded: imageData) ?? Data()) {
                        let swiftUIImage = Image(uiImage: image)
                                        DispatchQueue.main.async {
                                            completion(swiftUIImage)
                                        }
                    } else {
                        completion(nil)
                    }
                }
                
            case .failure(let error):
                print("Error fetching spot image: \(error)")
                completion(nil)
            }
        }
    }
    
    // Clear expired cache entries
    func cleanCache() {
        let now = Date()
        spotConditionsCache = spotConditionsCache.filter {
            now.timeIntervalSince($0.value.timestamp) < cacheExpirationInterval
        }
        
        spotForecastCache = spotForecastCache.filter {
                    now.timeIntervalSince($0.value.timestamp) < cacheExpirationInterval
                }
    }
}
