import SwiftUI
import MapKit

struct BuoyMarker: View {
    let buoy: BuoyLocation
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                // Main marker icon
                Image(systemName: "antenna.radiowaves.left.and.right.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .blue : .green)
                    .background(
                        Circle()
                            .fill(.white)
                            .frame(width: 20, height: 20)
                    )
                    .scaleEffect(isSelected ? 1.2 : 1.0)
                    .animation(.easeInOut(duration: 0.2), value: isSelected)
                
                // Buoy name label
                if isSelected {
                    Text(buoy.name)
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

struct BuoyMarker_Previews: PreviewProvider {
    static var previews: some View {
        let sampleBuoy = BuoyLocation(
            region_buoy: "NorthAtlantic",
            latitude: 55.186844,
            longitude: -7.59785,
            name: "M4"
        )
        
        VStack(spacing: 20) {
            BuoyMarker(buoy: sampleBuoy, isSelected: false) {
            }

            BuoyMarker(buoy: sampleBuoy, isSelected: true) {
            }
        }
        .padding()
    }
}
