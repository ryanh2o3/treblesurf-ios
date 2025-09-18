import SwiftUI

struct SpotConditionsDisplay: View {
    let conditions: ConditionData?
    let isLoading: Bool
    let timestamp: String?
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Current Conditions")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading conditions...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if let conditions = conditions {
                // Surf size
                HStack {
                    Image(systemName: "water.waves")
                        .foregroundColor(.blue)
                    Text("Surf: \(String(format: "%.1f", conditions.surfSize))ft")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Swell height and period
                HStack {
                    Image(systemName: "arrow.up.circle.fill")
                        .foregroundColor(.blue)
                    Text("Swell: \(String(format: "%.1f", conditions.swellHeight))ft @ \(String(format: "%.0f", conditions.swellPeriod))s")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Wind
                HStack {
                    Image(systemName: "wind")
                        .foregroundColor(.blue)
                    Text("Wind: \(String(format: "%.0f", conditions.windSpeed))mph \(conditions.formattedRelativeWindDirection)")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Temperature
                HStack {
                    Image(systemName: "thermometer")
                        .foregroundColor(.blue)
                    Text("Air: \(String(format: "%.0f", conditions.temperature))°C, Water: \(String(format: "%.0f", conditions.waterTemperature))°C")
                        .font(.caption)
                        .foregroundColor(.primary)
                }
                
                // Timestamp
                if let timestamp = timestamp {
                    HStack {
                        Image(systemName: "clock.fill")
                            .foregroundColor(.secondary)
                        Text("Updated: \(timestamp)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("No conditions available")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.top, 8)
    }
}

struct SpotConditionsDisplay_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 20) {
            SpotConditionsDisplay(
                conditions: nil,
                isLoading: true,
                timestamp: nil
            )
            
            // Sample conditions
            let sampleConditions = ConditionData(from: [
                "dateForecastedFor": "2025-01-15",
                "directionQuality": 8.5,
                "humidity": 75.0,
                "precipitation": 0.0,
                "pressure": 1013.0,
                "relativeWindDirection": "Offshore",
                "surfMessiness": "Clean",
                "surfSize": 4.5,
                "swellDirection": 270.0,
                "swellHeight": 4.2,
                "swellPeriod": 12.0,
                "temperature": 18.0,
                "waterTemperature": 14.0,
                "waveEnergy": 25.0,
                "windDirection": 90.0,
                "windSpeed": 15.0
            ])
            
            SpotConditionsDisplay(
                conditions: sampleConditions,
                isLoading: false,
                timestamp: "2 hours ago"
            )
        }
        .padding()
        .background(Color.gray.opacity(0.1))
    }
}
