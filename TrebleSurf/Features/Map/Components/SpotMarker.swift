import SwiftUI
import MapKit

struct SpotMarker: View {
    let spot: SpotData
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main marker icon
                Image(systemName: "figure.surfing")
                    .font(.system(size: 24))
                    .foregroundColor(.white)
                    .background(
                        Circle()
                            .fill(isSelected ? .blue : Color.blue.opacity(0.8))
                            .frame(width: 28, height: 28)
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                // Spot name label
                if isSelected {
                    Text(spot.name)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(.ultraThinMaterial)
                                .shadow(radius: 2)
                        )
                        .transition(.scale.combined(with: .opacity))
                }
            }
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SpotMarker_Previews: PreviewProvider {
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
        
        VStack(spacing: 20) {
            SpotMarker(spot: sampleSpot, isSelected: false) {
            }

            SpotMarker(spot: sampleSpot, isSelected: true) {
            }
        }
        .padding()
    }
}
