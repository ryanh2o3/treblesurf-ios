import Foundation
import MapKit
import Combine

class MapViewModel: ObservableObject {
    @Published var surfSpots: [SurfSpot] = []
    
    func loadSurfSpots() {
        // Placeholder method to load surf spots
        print("Loading surf spots...")
    }
}

// Basic model
struct SurfSpot: Identifiable {
    let id: String
    let name: String
    let coordinate: CLLocationCoordinate2D
}
