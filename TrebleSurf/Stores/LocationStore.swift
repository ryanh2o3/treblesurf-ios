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

class LocationStore: NSObject, ObservableObject, LocationStoreProtocol {
    static let shared = LocationStore()
    
    @Published var country: String = ""
    @Published var region: String = ""
    @Published var spot: String = ""
    @Published var coordinates: CLLocationCoordinate2D?
    @Published var isLocationServiceEnabled = false
    
    @AppStorage("savedLocations") private var savedLocationsData: Data = Data()
    @Published var savedLocations: [LocationData] = []
    
    private let locationManager = CLLocationManager()
    private let geocoder = CLGeocoder()
    
    private override init() {
        super.init()
        setupLocationManager()
        loadSavedLocations()
    }
    
    func setupLocationManager() {
        locationManager.delegate = self
        checkLocationAuthorization()
    }
    
    func checkLocationAuthorization() {
        switch locationManager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            locationManager.startUpdatingLocation()
            isLocationServiceEnabled = true
        case .denied, .restricted:
            isLocationServiceEnabled = false
        case .notDetermined:
            locationManager.requestWhenInUseAuthorization()
        @unknown default:
            break
        }
    }
    
    func loadSavedLocations() {
        guard !savedLocationsData.isEmpty else { return }
        
        do {
            savedLocations = try JSONDecoder().decode([LocationData].self, from: savedLocationsData)
        } catch {
            print("Error loading saved locations: \(error)")
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
            print("Error saving locations: \(error)")
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
}

extension LocationStore: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        checkLocationAuthorization()
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }
        
        // Reverse geocode to get location details
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, error in
            guard let self = self else { return }
            
            if let error = error {
                print("Reverse geocoding error: \(error.localizedDescription)")
                return
            }
            
            if let placemark = placemarks?.first {
                DispatchQueue.main.async {
                    self.country = placemark.country ?? ""
                    self.region = placemark.administrativeArea ?? ""
                    self.spot = placemark.locality ?? ""
                    self.coordinates = location.coordinate
                }
            }
        }
        
        // Stop updating location after getting it once
        locationManager.stopUpdatingLocation()
    }
    
    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        print("Location manager error: \(error.localizedDescription)")
        isLocationServiceEnabled = false
    }
    
    /// Reset the store to its initial state - clears all location data
    func resetToInitialState() {
        DispatchQueue.main.async {
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
            
            // Stop location updates
            self.locationManager.stopUpdatingLocation()
            
            print("LocationStore reset to initial state")
        }
    }
}
