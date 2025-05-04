import SwiftUI

struct CurrentConditionsCard: View {
    @EnvironmentObject var dataStore: DataStore//    var spotImagePath: String
    var spotImage: Image?

    
    var swellDirection: String {
        return "\(Int(dataStore.currentConditions.swellDirection))°"
    }
    
    var body: some View {
        VStack {
            HStack(spacing: 0) {
                // Left side with surf conditions
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(dataStore.currentConditions.surfSize) & \(dataStore.currentConditions.surfMessiness)")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundColor(Color(.black))
                    
                    Text("\(Int(dataStore.currentConditions.waveEnergy)) kJ/m²")
                        .font(.caption)
                        .foregroundColor(Color(.black))
                    
                    Text("\(dataStore.currentConditions.swellHeight, specifier: "%.1f")m @ \(dataStore.currentConditions.swellPeriod, specifier: "%.0f")s \(swellDirection)")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundColor(Color(.black))
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
                // Right side with image and directional arrow
                ZStack {
                    if let spotImage = spotImage {
                        spotImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.blue)
                        .rotationEffect(Angle(degrees: dataStore.currentConditions.swellDirection))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                
                
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            
            
            HStack(spacing: 0) {
                // Left side with surf conditions
                VStack(alignment: .leading, spacing: 4) {
                    Text(" \(dataStore.currentConditions.windSpeed) km/h")
                        .font(.caption)
                        .textCase(.uppercase)
                        .foregroundColor(Color(.black))
                    
                    Text("\(dataStore.currentConditions.windDirection) degrees")
                        .font(.caption)
                        .foregroundColor(Color(.black))
                
                }
                .padding(.vertical, 12)
                .padding(.horizontal, 12)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
                // Right side with image and directional arrow
                ZStack {
                    if let spotImage = spotImage {
                        spotImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    
                    Image(systemName: "arrow.down")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.white)
                        .rotationEffect(Angle(degrees: dataStore.currentConditions.windDirection))
                }
                .frame(maxWidth: .infinity)
                .padding(12)
                
                
            }
            .frame(maxWidth: .infinity, maxHeight: 200)
            .background(Color.gray.opacity(0.2))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding(.horizontal, 12)
        
    }
}
