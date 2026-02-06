import Foundation
import MapKit
import Combine
import SwiftUI

@MainActor
class MapViewModel: BaseViewModel {
    @Published var surfSpots: [SpotData] = []
    @Published var buoys: [BuoyLocation] = []
    @Published var selectedSpot: SpotData?
    @Published var selectedBuoy: BuoyLocation?
    @Published var selectedSpotConditions: ConditionData?
    @Published var isLoadingConditions: Bool = false
    @Published var showingSpotDetails: Bool = false
    @Published var showingBuoyDetails: Bool = false
    
    private var cancellables = Set<AnyCancellable>()
    private let dataStore: DataStore
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
        loadMapData()
    }
    
    func loadMapData() {
        executeTask(context: "Load Map Data") {
            // Load spots and buoys concurrently
            try await withThrowingTaskGroup(of: Void.self) { group in
                group.addTask { try await self.loadSurfSpots() }
                group.addTask { try await self.loadBuoys() }
                for try await _ in group { }
            }
        }
    }
    
    private func loadSurfSpots() async throws {
        logger.log("Loading surf spots for region: Donegal", level: .info, category: .general)
        let spots = try await dataStore.fetchRegionSpots(region: "Donegal")
        self.surfSpots = spots
        self.logger.log("Loaded \(spots.count) surf spots", level: .info, category: .general)
    }
    
    private func loadBuoys() async throws {
        logger.log("Loading buoys for region: NorthAtlantic", level: .info, category: .general)
        let buoyResponses = try await apiClient.fetchBuoys(region: "NorthAtlantic")
        self.buoys = buoyResponses
        logger.log("Loaded \(buoyResponses.count) buoys", level: .info, category: .general)
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
    func loadCurrentConditions(for spot: SpotData) {
        isLoadingConditions = true
        Task { [weak self] in
            guard let self = self else { return }
            let success = await self.dataStore.fetchConditions(for: spot.id)
            self.isLoadingConditions = false
            if success {
                // Get conditions from the DataStore's currentConditions property
                self.selectedSpotConditions = self.dataStore.currentConditions
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
