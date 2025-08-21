import SwiftUI

private let rowHeight: CGFloat = 80
private let rowSpacing: CGFloat = 4

struct SurfTableView: View {
    let entries: [ForecastEntry]
    var onEntryVisible: ((ForecastEntry) -> Void)? = nil
    @State private var scrollOffset: CGFloat = 0
    
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
            ScrollViewReader { proxy in
                VStack(spacing: 24) {
                    // Hidden tracking view at the top
                    GeometryReader { geometry in
                        Color.clear
                            .preference(key: ScrollOffsetPreferenceKey.self,
                                        value: geometry.frame(in: .global).minY)
                    }
                    .frame(height: 0)
                    
                    ForEach(sortedDays, id: \.self) { day in
                        if let dayEntries = entriesByDay[day] {
                            CombinedForecastCard(day: day, entries: dayEntries, onEntryVisible: onEntryVisible)
                                .shadow(color: Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
                                .id(day)
                        }
                    }
                }
                .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                    scrollOffset = value
                }
            }
        }
    }
    
    // Helper functions
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

// Combined forecast card with swipeable content
struct CombinedForecastCard: View {
    let day: Date
    let entries: [ForecastEntry]
    var onEntryVisible: ((ForecastEntry) -> Void)? = nil
    @State private var currentPage = 0
    
    var body: some View {
        VStack(alignment: .leading) {
            // Day header - always visible
            Text(day, style: .date)
                .font(.headline)
                .padding(.horizontal)
                .padding(.bottom, 4) // Added spacing
            
            // Common table header - stays in place
            HStack {
                if currentPage == 0 {
                    Text("Surf")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("Swell")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Wind")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                } else {
                    
                    Text("Temp")
                        .frame(maxWidth: .infinity, alignment: .center)
                    Text("Weather")
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
            .font(.caption)
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12) // Increased bottom padding
            HStack(spacing: 8) {
                
                VStack(alignment: .leading, spacing: rowSpacing) {
                                    ForEach(entries) { entry in
                                        Text(timeFormatter.string(from: entry.dateForecastedFor))
                                            .font(.footnote)
                                            .frame(height: rowHeight, alignment: .center)
                                            .rotationEffect(.degrees(90))
                                    }
                                }
        
                                .frame(width: 20)
                // Swipeable content
                TabView(selection: $currentPage) {
                    SurfContent(entries: entries, onEntryVisible: onEntryVisible)
                        .tag(0)
                    
                    WeatherContent(entries: entries)
                        .tag(1)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
            }
            // Page indicator dots
            HStack(spacing: 8) {
                ForEach(0..<2) { index in
                    Circle()
                        .fill(currentPage == index ? Color.blue : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                        .onTapGesture {
                            withAnimation {
                                currentPage = index
                            }
                        }
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 8)
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(10)
    }
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "H" // Displays hours in 24-hour format without minutes
        return formatter
    }}

// Surf and wind content
struct SurfContent: View {
    let entries: [ForecastEntry]
    var onEntryVisible: ((ForecastEntry) -> Void)? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { index, entry in
                HStack(alignment: .center) {
                    // Surf Cell
                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(getSwellColor(for: entry))
                            .frame(width: 10, height: 40)
                            
                        VStack(alignment: .leading, spacing: 2) {
                            Text(entry.surfSize > 0 ? "\(writtenSurfSize(entry.surfSize)) & \(entry.surfMessiness)" : "Flat")
                                .font(.footnote)
                            Text("\(Int(entry.waveEnergy)) kj/m²")
                                .font(.caption2)
                        }
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
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Wind Cell
                    HStack {
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
                .frame(height: rowHeight)
                .id("entry-\(index)")
                .onAppear {
                    onEntryVisible?(entry) // Notify when entry is visible
                }
                .background(
                    GeometryReader { geometry in
                        Color.clear
                            .preference(
                                key: EntryPreferenceKey.self,
                                value: [EntryPreference(entry: entry, rect: geometry.frame(in: .named("surfContent")))]
                            )
                            .onAppear {
                                print("Geometry frame for \(entry.dateForecastedFor): \(geometry.frame(in: .named("surfContent")))")
                            }
                    }
                )
            }
        }
        .coordinateSpace(name: "surfContent")
        .onPreferenceChange(EntryPreferenceKey.self) { preferences in
                   let screenMidPoint = UIScreen.main.bounds.height / 2
                   
                   // Find entry closest to the screen midpoint
                   let sortedByDistanceToCenter = preferences.sorted {
                       abs($0.rect.midY - screenMidPoint) < abs($1.rect.midY - screenMidPoint)
                   }
                   
                   if let closestEntry = sortedByDistanceToCenter.first {
                       onEntryVisible?(closestEntry.entry)
                   }
               }
            
    }
    
    // Helper functions
    func writtenSurfSize(_ size: Double) -> String {
        SurfTableView(entries: []).writtenSurfSize(size)
    }
    
    func getDirection(from degrees: Double) -> String {
        SurfTableView(entries: []).getDirection(from: degrees)
    }
    
    func getSwellColor(for entry: ForecastEntry) -> Color {
        SurfTableView(entries: []).getSwellColor(for: entry)
    }
    
    func getWindColor(for entry: ForecastEntry) -> Color {
        SurfTableView(entries: []).getWindColor(for: entry)
    }
    
    
}

// Weather content
struct WeatherContent: View {
    let entries: [ForecastEntry]
    
    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(entries) { entry in
                HStack(alignment: .center) {
                    // Temperature Cell
                    VStack(spacing: 8) {
                        Text("\(Int(entry.temperature))°C")
                            .font(.footnote)
                        
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.caption2)
                                .foregroundColor(.blue)
                            Text("\(Int(entry.precipitation * 100))%")
                                .font(.caption2)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                    
                    // Weather conditions Cell
                    VStack(spacing: 8) {
                        Text("\(Int(entry.temperature))°C")
                            .font(.caption)
                        
                        Text("Press: \(Int(entry.pressure)) hPa")
                            .font(.caption2)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .frame(height: rowHeight)
            }
        }
    }
    
    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter
    }
    
//    func weatherIcon(for entry: ForecastEntry) -> String {
//        // Basic weather icon selection based on condition
//        let condition = entry.weatherCondition?.lowercased() ?? ""
//
//        if condition.contains("rain") {
//            return "cloud.rain"
//        } else if condition.contains("cloud") {
//            return "cloud"
//        } else if condition.contains("sun") || condition.contains("clear") {
//            return "sun.max"
//        } else {
//            return "cloud.sun"
//        }
//    }
}

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// Add this preference key for tracking entry positions
struct EntryPreference: Equatable {
    let entry: ForecastEntry
    let rect: CGRect
    
    static func == (lhs: EntryPreference, rhs: EntryPreference) -> Bool {
        lhs.entry.id == rhs.entry.id
    }
}

struct EntryPreferenceKey: PreferenceKey {
    static var defaultValue: [EntryPreference] = []
    static func reduce(value: inout [EntryPreference], nextValue: () -> [EntryPreference]) {
        value.append(contentsOf: nextValue())
    }
}
