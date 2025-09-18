import Foundation
import MapKit
import Combine
import SwiftUI

class MapViewModel: ObservableObject {
    @Published var surfSpots: [SpotData] = []
    @Published var buoys: [BuoyLocation] = []
    @Published var selectedSpot: SpotData?
    @Published var selectedBuoy: BuoyLocation?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?
    @Published var selectedSpotConditions: ConditionData?
    @Published var isLoadingConditions: Bool = false
    @Published var showingSpotDetails: Bool = false
    @Published var showingBuoyDetails: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let dataStore = DataStore.shared
    
    init() {
        loadMapData()
    }
    
    func loadMapData() {
        isLoading = true
        errorMessage = nil
        
        // Load spots and buoys concurrently
        let spotsTask = Task { await loadSurfSpots() }
        let buoysTask = Task { await loadBuoys() }
        
        // Wait for both to complete
        Task {
            await withTaskGroup(of: Void.self) { group in
                group.addTask { await spotsTask.value }
                group.addTask { await buoysTask.value }
            }
            
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
    
    @MainActor
    private func loadSurfSpots() async {
        do {
            try await withCheckedThrowingContinuation { continuation in
                dataStore.fetchRegionSpots(region: "Donegal") { [weak self] result in
                    switch result {
                    case .success(let spots):
                        Task { @MainActor in
                            self?.surfSpots = spots
                        }
                        continuation.resume()
                    case .failure(let error):
                        Task { @MainActor in
                            self?.errorMessage = "Failed to load spots: \(error.localizedDescription)"
                        }
                        continuation.resume(throwing: error)
                    }
                }
            }
        } catch {
            print("Error loading surf spots: \(error)")
        }
    }
    
    @MainActor
    private func loadBuoys() async {
        do {
            let buoyResponses = try await withCheckedThrowingContinuation { continuation in
                APIClient.shared.fetchBuoys(region: "NorthAtlantic") { result in
                    continuation.resume(with: result)
                }
            }
            
            self.buoys = buoyResponses
        } catch {
            print("Error loading buoys: \(error)")
            self.errorMessage = "Failed to load buoys: \(error.localizedDescription)"
        }
    }
    
    func selectSpot(_ spot: SpotData) {
        selectedSpot = spot
        selectedBuoy = nil
        selectedSpotConditions = nil
        loadCurrentConditions(for: spot)
    }
    
    func selectBuoy(_ buoy: BuoyLocation) {
        selectedBuoy = buoy
        selectedSpot = nil
        selectedSpotConditions = nil
    }
    
    func clearSelection() {
        selectedSpot = nil
        selectedBuoy = nil
        selectedSpotConditions = nil
        showingSpotDetails = false
        showingBuoyDetails = false
    }
    
    func showSpotDetails() {
        showingSpotDetails = true
    }
    
    func showBuoyDetails() {
        showingBuoyDetails = true
    }
    
    func zoomOutToOverview() {
        // This will be handled by the MapView's double-tap gesture
        clearSelection()
    }
    
    // Load current conditions for a selected spot
    private func loadCurrentConditions(for spot: SpotData) {
        isLoadingConditions = true
        
        // Use the existing DataStore method to fetch conditions
        dataStore.fetchConditions(for: spot.id) { [weak self] success in
            DispatchQueue.main.async {
                self?.isLoadingConditions = false
                if success {
                    // Get conditions from the DataStore's currentConditions property
                    self?.selectedSpotConditions = self?.dataStore.currentConditions
                }
            }
        }
    }
    
    // Convert SpotData to CLLocationCoordinate2D
    func coordinateForSpot(_ spot: SpotData) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: spot.latitude, longitude: spot.longitude)
    }
    
    // Convert BuoyLocation to CLLocationCoordinate2D
    func coordinateForBuoy(_ buoy: BuoyLocation) -> CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: buoy.latitude, longitude: buoy.longitude)
    }
    
    // Get region that encompasses all spots and buoys
    func getMapRegion() -> MKCoordinateRegion {
        guard !surfSpots.isEmpty || !buoys.isEmpty else {
            // Default to Donegal if no data
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.186844, longitude: -7.59785),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        }
        
        var allCoordinates: [CLLocationCoordinate2D] = []
        
        // Add spot coordinates
        allCoordinates.append(contentsOf: surfSpots.map { coordinateForSpot($0) })
        
        // Add buoy coordinates
        allCoordinates.append(contentsOf: buoys.map { coordinateForBuoy($0) })
        
        guard !allCoordinates.isEmpty else {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: 55.186844, longitude: -7.59785),
                span: MKCoordinateSpan(latitudeDelta: 1.0, longitudeDelta: 1.0)
            )
        }
        
        // Calculate bounds
        let latitudes = allCoordinates.map { $0.latitude }
        let longitudes = allCoordinates.map { $0.longitude }
        
        let minLat = latitudes.min() ?? 55.0
        let maxLat = latitudes.max() ?? 56.0
        let minLon = longitudes.min() ?? -8.0
        let maxLon = longitudes.max() ?? -7.0
        
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        
        // Use larger spans to reduce marker flickering
        let span = MKCoordinateSpan(
            latitudeDelta: max((maxLat - minLat) * 1.5, 0.5), // Minimum 0.5 degree span
            longitudeDelta: max((maxLon - minLon) * 1.5, 0.5)
        )
        
        return MKCoordinateRegion(center: center, span: span)
    }
    
    // Get a more stable region that's less prone to marker flickering
    func getStableMapRegion() -> MKCoordinateRegion {
        let baseRegion = getMapRegion()
        
        // Ensure minimum span to reduce flickering
        let minSpan: Double = 0.3
        let adjustedSpan = MKCoordinateSpan(
            latitudeDelta: max(baseRegion.span.latitudeDelta, minSpan),
            longitudeDelta: max(baseRegion.span.longitudeDelta, minSpan)
        )
        
        return MKCoordinateRegion(center: baseRegion.center, span: adjustedSpan)
    }
    
    // Get an ultra-stable region with large buffers to minimize marker flickering
    func getUltraStableMapRegion() -> MKCoordinateRegion {
        let baseRegion = getMapRegion()
        
        // Use much larger spans to create stable viewing areas
        let ultraStableSpan = MKCoordinateSpan(
            latitudeDelta: max(baseRegion.span.latitudeDelta * 2.0, 1.0), // Double the span, minimum 1.0
            longitudeDelta: max(baseRegion.span.longitudeDelta * 2.0, 1.0)
        )
        
        return MKCoordinateRegion(center: baseRegion.center, span: ultraStableSpan)
    }
    
    // Check if a coordinate is within a stable viewing area
    func isCoordinateInStableArea(_ coordinate: CLLocationCoordinate2D, currentRegion: MKCoordinateRegion) -> Bool {
        let buffer: Double = 0.1 // 0.1 degree buffer around the visible area
        
        let minLat = currentRegion.center.latitude - (currentRegion.span.latitudeDelta / 2) - buffer
        let maxLat = currentRegion.center.latitude + (currentRegion.span.latitudeDelta / 2) + buffer
        let minLon = currentRegion.center.longitude - (currentRegion.span.longitudeDelta / 2) - buffer
        let maxLon = currentRegion.center.longitude + (currentRegion.span.longitudeDelta / 2) + buffer
        
        return coordinate.latitude >= minLat && coordinate.latitude <= maxLat &&
               coordinate.longitude >= minLon && coordinate.longitude <= maxLon
    }
    
    // Get a zoomed region centered on a specific spot
    func getZoomedRegionForSpot(_ spot: SpotData) -> MKCoordinateRegion {
        let coordinate = coordinateForSpot(spot)
        let zoomedSpan = MKCoordinateSpan(
            latitudeDelta: 0.1, // Zoom in to show more detail
            longitudeDelta: 0.1
        )
        return MKCoordinateRegion(center: coordinate, span: zoomedSpan)
    }
    
    // Get a zoomed region centered on a specific buoy
    func getZoomedRegionForBuoy(_ buoy: BuoyLocation) -> MKCoordinateRegion {
        let coordinate = coordinateForBuoy(buoy)
        let zoomedSpan = MKCoordinateSpan(
            latitudeDelta: 0.1, // Zoom in to show more detail
            longitudeDelta: 0.1
        )
        return MKCoordinateRegion(center: coordinate, span: zoomedSpan)
    }
    
    // Get a zoomed region centered on a coordinate with custom zoom level
    func getZoomedRegion(center: CLLocationCoordinate2D, zoomLevel: Double) -> MKCoordinateRegion {
        let span = MKCoordinateSpan(
            latitudeDelta: zoomLevel,
            longitudeDelta: zoomLevel
        )
        return MKCoordinateRegion(center: center, span: span)
    }
}

// Basic model
struct SurfSpot: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}
