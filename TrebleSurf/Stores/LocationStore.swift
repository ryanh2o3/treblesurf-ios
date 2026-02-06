// LocationStore.swift
import Foundation
import CoreLocation
import SwiftUI

struct LocationData: Codable, Identifiable {
    var id = UUID()
    let country: String
    let region: String
    let spot: String
    let latitude: Double?
    let longitude: Double?
    
    var coordinates: CLLocationCoordinate2D? {
        guard let latitude = latitude, let longitude = longitude else { return nil }
        return CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
    
    enum CodingKeys: String, CodingKey {
        case id, country, region, spot, latitude, longitude
    }
}

@MainActor
class LocationStore: NSObject, ObservableObject, LocationStoreProtocol {
    @Published var country: String = ""
    @Published var region: String = ""
    @Published var spot: String = ""
    @Published var coordinates: CLLocationCoordinate2D?
    @Published var isLocationServiceEnabled = false
    
    @AppStorage("savedLocations") private var savedLocationsData: Data = Data()
    @Published var savedLocations: [LocationData] = []
    
    // Removed CLLocationManager logic as it is unused and authorization keys were removed.
    
    nonisolated override init() {
        super.init()
        Task { @MainActor in
            self.loadSavedLocations()
        }
    }
    
    func setupLocationManager() {
        // No-op
    }
    
    func checkLocationAuthorization() {
        // No-op
        isLocationServiceEnabled = false
    }
    
    func loadSavedLocations() {
        guard !savedLocationsData.isEmpty else { return }
        
        do {
            savedLocations = try JSONDecoder().decode([LocationData].self, from: savedLocationsData)
        } catch {

        }
    }
    
    func saveLocation(_ location: LocationData) {
        if !savedLocations.contains(where: {
            $0.country == location.country &&
            $0.region == location.region &&
            $0.spot == location.spot
        }) {
            savedLocations.append(location)
            saveToDisk()
        }
    }
    
    func removeLocation(at indexSet: IndexSet) {
        savedLocations.remove(atOffsets: indexSet)
        saveToDisk()
    }
    
    func removeLocation(_ location: LocationData) {
        if let index = savedLocations.firstIndex(where: {
            $0.country == location.country &&
            $0.region == location.region &&
            $0.spot == location.spot
        }) {
            savedLocations.remove(at: index)
            saveToDisk()
        }
    }
    
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(savedLocations)
            savedLocationsData = data
        } catch {

        }
    }
    
    func setCurrentLocation(country: String, region: String, spot: String, coordinates: CLLocationCoordinate2D? = nil) {
        self.country = country
        self.region = region
        self.spot = spot
        self.coordinates = coordinates
    }
    
    func getCurrentLocationData() -> LocationData? {
        guard !country.isEmpty && !region.isEmpty && !spot.isEmpty else { return nil }
        
        return LocationData(
            country: country,
            region: region,
            spot: spot,
            latitude: coordinates?.latitude,
            longitude: coordinates?.longitude
        )
    }
    
    /// Reset the store to its initial state - clears all location data
    func resetToInitialState() {
        // Already on MainActor, no need for DispatchQueue
        // Reset all published properties to initial values
        self.country = ""
        self.region = ""
        self.spot = ""
        self.coordinates = nil
        self.isLocationServiceEnabled = false
        self.savedLocations = []
        
        // Clear saved locations from disk
        self.savedLocationsData = Data()
        UserDefaults.standard.removeObject(forKey: "savedLocations")
        UserDefaults.standard.synchronize()
    }
}
