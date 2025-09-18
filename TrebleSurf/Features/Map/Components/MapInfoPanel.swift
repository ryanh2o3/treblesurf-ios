import SwiftUI
import MapKit

struct MapInfoPanel: View {
    let selectedSpot: SpotData?
    let selectedBuoy: BuoyLocation?
    let spotConditions: ConditionData?
    let isLoadingConditions: Bool
    let conditionsTimestamp: String?
    let onClose: () -> Void
    let onZoomOut: () -> Void
    let onViewDetails: () -> Void
    
    var body: some View {
        if selectedSpot != nil || selectedBuoy != nil {
            VStack(alignment: .leading, spacing: 12) {
                // Header with close button and zoom out
                HStack {
                    Text(selectedSpot != nil ? "Surf Spot" : "Buoy")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    // Zoom out button
                    Button(action: onZoomOut) {
                        Image(systemName: "minus.magnifyingglass")
                            .font(.title2)
                            .foregroundColor(.blue)
                    }
                    .padding(.trailing, 8)
                    
                    // Close button
                    Button(action: onClose) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.secondary)
                    }
                }
                
                // Content based on selection
                if let spot = selectedSpot {
                    spotInfoView(spot)
                } else if let buoy = selectedBuoy {
                    buoyInfoView(buoy)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(.ultraThinMaterial)
                    .shadow(radius: 8)
            )
            .padding(.horizontal)
            .transition(.move(edge: .bottom).combined(with: .opacity))
        }
    }
    
    private func spotInfoView(_ spot: SpotData) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Spot name
            Text(spot.name)
                .font(.title3)
                .fontWeight(.bold)
            
            // Location details
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.blue)
                Text("\(spot.countryRegionSpot)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Spot type
            HStack {
                Image(systemName: "figure.surfing")
                    .foregroundColor(.blue)
                Text(spot.type)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Ideal swell direction
            HStack {
                Image(systemName: "arrow.up.circle.fill")
                    .foregroundColor(.blue)
                Text("Ideal swell: \(spot.idealSwellDirection)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Beach direction
            HStack {
                Image(systemName: "compass.fill")
                    .foregroundColor(.blue)
                Text("Beach faces: \(spot.beachDirection)°")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Current conditions using the new component
            SpotConditionsDisplay(
                conditions: spotConditions,
                isLoading: isLoadingConditions,
                timestamp: conditionsTimestamp
            )
            
            // View More Details button
            Button(action: onViewDetails) {
                HStack {
                    Text("View More Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.blue)
                )
            }
            .padding(.top, 8)
        }
    }
    
    private func buoyInfoView(_ buoy: BuoyLocation) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            // Buoy name
            Text(buoy.name)
                .font(.title3)
                .fontWeight(.bold)
            
            // Region
            HStack {
                Image(systemName: "antenna.radiowaves.left.and.right")
                    .foregroundColor(.green)
                Text(buoy.region_buoy)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Coordinates
            HStack {
                Image(systemName: "location.fill")
                    .foregroundColor(.green)
                Text(String(format: "%.4f, %.4f", buoy.latitude, buoy.longitude))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // View More Details button
            Button(action: onViewDetails) {
                HStack {
                    Text("View More Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Image(systemName: "arrow.right")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.green)
                )
            }
            .padding(.top, 8)
        }
    }
}

struct MapInfoPanel_Previews: PreviewProvider {
    static var previews: some View {
        let sampleSpot = SpotData(
            beachDirection: 270,
            idealSwellDirection: "W",
            latitude: 55.186844,
            longitude: -7.59785,
            type: "Beach",
            countryRegionSpot: "Ireland/Donegal/Bundoran",
            image: "",
            imageString: nil
        )
        
        let sampleBuoy = BuoyLocation(
            region_buoy: "NorthAtlantic",
            latitude: 55.186844,
            longitude: -7.59785,
            name: "M4"
        )
        
        VStack(spacing: 20) {
            MapInfoPanel(
                selectedSpot: sampleSpot,
                selectedBuoy: nil,
                spotConditions: nil,
                isLoadingConditions: true,
                conditionsTimestamp: nil,
                onClose: {},
                onZoomOut: {},
                onViewDetails: {}
            )
            
            MapInfoPanel(
                selectedSpot: nil,
                selectedBuoy: sampleBuoy,
                spotConditions: nil,
                isLoadingConditions: true,
                conditionsTimestamp: nil,
                onClose: {},
                onZoomOut: {},
                onViewDetails: {}
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
