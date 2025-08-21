import SwiftUI

struct WeatherTableView: View {
    let entries: [ForecastEntry]
    
    // Group entries by day
    var entriesByDay: [Date: [ForecastEntry]] {
        let calendar = Calendar.current
        var result = [Date: [ForecastEntry]]()
        
        for entry in entries {
            // Remove time component to group by day
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.dateForecastedFor)
            if let dayDate = calendar.date(from: dateComponents) {
                if result[dayDate] == nil {
                    result[dayDate] = [entry]
                } else {
                    result[dayDate]!.append(entry)
                }
            }
        }
        
        return result
    }
    
    // Sorted days
    var sortedDays: [Date] {
        entriesByDay.keys.sorted()
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                ForEach(sortedDays, id: \.self) { day in
                    if let dayEntries = entriesByDay[day] {
                        WeatherForecastCard(day: day, entries: dayEntries)
                            .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                    }
                }
            }
            .padding()
        }
    }
    
    // Helper functions remain the same
    func writtenSurfSize(_ size: Double) -> String {
        switch size {
        case 0: return "Flat"
        case 0..<1: return "Small"
        case 1..<2: return "Medium"
        default: return "Large"
        }
    }
    
    func getDirection(from degrees: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return dirs[index]
    }
    
    func getSwellColor(for entry: ForecastEntry) -> Color {
        switch writtenSurfSize(entry.surfSize) {
        case "Flat": return .blue
        case "Small": return .green
        case "Medium": return .orange
        default: return .red
        }
    }
    
    func getWindColor(for entry: ForecastEntry) -> Color {
        switch entry.surfMessiness.lowercased() {
        case "clean": return .green
        case "choppy": return .orange
        default: return .gray
        }
    }
}

// New component for day cards
struct WeatherForecastCard: View {
    let day: Date
    let entries: [ForecastEntry]
    
    var body: some View {
        VStack(alignment: .leading) {
            // Day header
            Text(day, style: .date)
                .font(.headline)
                .padding(.horizontal)
            
            // Table header
            HStack {
                Text("Weather")
                Spacer()
                Text("Pressure")
                Spacer()
                Text("Humidity")
            }
            .font(.caption)
            .padding(.horizontal)
            
            // Day entries
            ForEach(entries) { entry in
                HStack(alignment: .center) {
                    // Surf Cell
                    VStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getSwellColor(for: entry))
                            .frame(width: 10, height: 40)
                            
                        Text(entry.surfSize > 0 ? "\(writtenSurfSize(entry.surfSize)) & \(entry.surfMessiness)" : "Flat")
                            .font(.footnote)
                        Text("\(Int(entry.waveEnergy)) kj/m²")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // Swell Cell
                    VStack {
                        Text(getDirection(from: entry.swellDirection))
                            .font(.caption)
                        Image(systemName: "arrow.down")
                            .rotationEffect(.degrees(entry.swellDirection))
                        Text("\(entry.swellHeight, specifier: "%.1f")m at \(Int(entry.swellPeriod))s")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity)
                    
                    // Wind Cell
                    VStack {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getWindColor(for: entry))
                            .frame(width: 10, height: 40)
                        
                        Text("\(entry.relativeWindDirection) / \(getDirection(from: entry.windDirection))")
                            .font(.caption2)
                        Image(systemName: "arrow.down")
                            .rotationEffect(.degrees(entry.windDirection))
                        Text("\(Int(entry.windSpeed * 3.6)) km/h")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    
    // Helper functions - standalone implementations
    func writtenSurfSize(_ size: Double) -> String {
        switch size {
        case 0: return "Flat"
        case 0..<1: return "Small"
        case 1..<2: return "Medium"
        default: return "Large"
        }
    }
    
    func getDirection(from degrees: Double) -> String {
        let dirs = ["N", "NE", "E", "SE", "S", "SW", "W", "NW"]
        let index = Int((degrees + 22.5) / 45.0) % 8
        return dirs[index]
    }
    
    func getSwellColor(for entry: ForecastEntry) -> Color {
        switch writtenSurfSize(entry.surfSize) {
        case "Flat": return .blue
        case "Small": return .green
        case "Medium": return .orange
        default: return .red
        }
    }
    
    func getWindColor(for entry: ForecastEntry) -> Color {
        switch entry.surfMessiness.lowercased() {
        case "clean": return .green
        case "choppy": return .orange
        default: return .gray
        }
    }
}
