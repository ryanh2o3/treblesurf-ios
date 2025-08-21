
// SpotForecastView.swift
import SwiftUI
import Charts


struct SpotForecastView: View {
    @StateObject private var viewModel: SpotForecastViewModel
        @EnvironmentObject var dataStore: DataStore
        var spotId: String
        @State private var spotImage: Image? = nil
            @State private var currentForecastEntry: ForecastEntry? = nil
    @State private var scrollOffset: CGFloat = 0
    @State private var selectedCardIndex: Int = 0
        
    
    init(spotId: String) {
        self.spotId = spotId
        _viewModel = StateObject(wrappedValue: SpotForecastViewModel(dataStore: DataStore.shared))
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Sticky header with spot image and dynamic arrow
                ZStack(alignment: .bottom) {
                    if let spotImage = spotImage {
                        spotImage
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    }
                    
                    // Overlay with dynamic swell direction arrow and key data
                    VStack(spacing: 12) {
                        // Key data display
                        if let entry = currentForecastEntry {
                            VStack(spacing: 8) {
                                HStack(spacing: 16) {
                                    VStack(spacing: 4) {
                                        Text("Swell")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(entry.swellHeight, specifier: "%.1f")m")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("Wind")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(Int(entry.windSpeed * 3.6)) km/h")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                    
                                    VStack(spacing: 4) {
                                        Text("Temp")
                                            .font(.caption)
                                            .foregroundColor(.white)
                                        Text("\(Int(entry.temperature))°C")
                                            .font(.title2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.white)
                                    }
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.black.opacity(0.6))
                                .cornerRadius(12)
                            }
                        }
                        
                        // Dynamic swell direction arrow that adjusts based on selected card
                        Image(systemName: "arrow.down")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundColor(.white)
                            .rotationEffect(Angle(degrees: currentForecastEntry?.swellDirection ?? dataStore.currentConditions.swellDirection))
                            .animation(.easeInOut(duration: 0.4), value: currentForecastEntry?.swellDirection)
                            .scaleEffect(1.0)
                            .padding(.bottom, 8)
                    }
                    .padding(.bottom, 8)
                }
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 6)
                .padding(.bottom, 8)
                
                // Mode toggle buttons
                HStack {
                    ForEach(ForecastViewMode.allCases) { mode in
                        Button(action: {
                            viewModel.setViewMode(mode)
                        }) {
                            Text(mode.rawValue)
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(viewModel.selectedMode == mode ? Color.blue : Color(.systemGray5))
                                )
                                .foregroundColor(viewModel.selectedMode == mode ? .white : .primary)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray6))
                )
                .padding(.horizontal, 6)
                .padding(.bottom, 16)
                
                // Horizontal scrolling forecast cards
                VStack(spacing: 20) {
                    // Dynamic day header that shows the current selected card's day
                    if !viewModel.filteredEntries.isEmpty, let currentEntry = currentForecastEntry {
                        let currentDate = Calendar.current.startOfDay(for: currentEntry.dateForecastedFor)
                        let isCurrentDay = isCurrentDay(currentDate)
                        
                        HStack {
                            Text(dayHeaderFormatter.string(from: currentEntry.dateForecastedFor))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(isCurrentDay ? .blue : .primary)
                            
                            Spacer()
                            
                            // Show time of selected forecast
                            Text(timeFormatter.string(from: currentEntry.dateForecastedFor))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(Color(.systemGray6))
                        )
                        
                        // Underline for current day
                        if isCurrentDay {
                            Rectangle()
                                .fill(Color.blue)
                                .frame(height: 2)
                                .padding(.horizontal, 16)
                        }
                    }
                    
                    // Horizontal scrolling cards with day separators
                    ScrollViewReader { scrollProxy in
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 0) {
                                ForEach(Array(groupedForecasts.keys.sorted()), id: \.self) { date in
                                    let dayEntries = groupedForecasts[date] ?? []
                                    
                                    HStack(spacing: 12) {
                                        ForEach(Array(dayEntries.enumerated()), id: \.element.id) { index, entry in
                                            let globalIndex = viewModel.filteredEntries.firstIndex(of: entry) ?? 0
                                            ForecastCard(
                                                entry: entry,
                                                isSelected: globalIndex == selectedCardIndex,
                                                onTap: {
                                                    selectedCardIndex = globalIndex
                                                    currentForecastEntry = entry
                                                }
                                            )
                                            .id(globalIndex)
                                        }
                                    }
                                    
                                    // Day separator (except for last day)
                                    if date != groupedForecasts.keys.sorted().last {
                                        Rectangle()
                                            .fill(Color.gray.opacity(0.3))
                                            .frame(width: 2, height: 180)
                                            .padding(.horizontal, 30)
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: ScrollOffsetPreferenceKey.self, value: geo.frame(in: .named("scroll")).minX)
                                        .onAppear {
                                            // Initial offset
                                            scrollOffset = geo.frame(in: .named("scroll")).minX
                                        }
                                        .onChange(of: geo.frame(in: .named("scroll")).minX) { newValue in
                                            // More direct tracking of scroll position
                                            scrollOffset = newValue
                                            updateSelectedCard(from: newValue, geometry: geometry)
                                        }
                                }
                            )
                        }
                        .coordinateSpace(name: "scroll")
                        .onPreferenceChange(ScrollOffsetPreferenceKey.self) { value in
                            scrollOffset = value
                            // Debug: print the offset to see if it's updating
                            print("Scroll offset: \(value)")
                            updateSelectedCard(from: scrollOffset, geometry: geometry)
                        }
                        .onAppear {
                            // Select first card by default
                            if !viewModel.filteredEntries.isEmpty {
                                selectedCardIndex = 0
                                currentForecastEntry = viewModel.filteredEntries[0]
                            }
                        }
                        .onChange(of: scrollOffset) { newOffset in
                            // Update selection when scroll offset changes
                            updateSelectedCard(from: newOffset, geometry: geometry)
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIDevice.orientationDidChangeNotification)) { _ in
                            // Force update when orientation changes
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                updateSelectedCard(from: scrollOffset, geometry: geometry)
                            }
                        }
                    }
                }
            }
        }
        .frame(height: UIScreen.main.bounds.height)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .onAppear {
            viewModel.fetchForecast(for: spotId) { success in
                if !success {
                    print("Failed to fetch conditions for spot: \(spotId)")
                }
                // Set the first entry as selected when forecast loads
                DispatchQueue.main.async {
                    if let firstEntry = viewModel.filteredEntries.first {
                        currentForecastEntry = firstEntry
                    }
                }
            }
            dataStore.fetchSpotImage(for: spotId) { image in
                self.spotImage = image
            }
        }
        .onChange(of: viewModel.filteredEntries) { entries in
            // Update selection when entries change
            if currentForecastEntry == nil, let firstEntry = entries.first {
                currentForecastEntry = firstEntry
            }
        }
    }
    
    // Group forecasts by day
    private var groupedForecasts: [Date: [ForecastEntry]] {
        let calendar = Calendar.current
        var grouped: [Date: [ForecastEntry]] = [:]
        
        for entry in viewModel.filteredEntries {
            let dateComponents = calendar.dateComponents([.year, .month, .day], from: entry.dateForecastedFor)
            if let date = calendar.date(from: dateComponents) {
                if grouped[date] == nil {
                    grouped[date] = []
                }
                grouped[date]?.append(entry)
            }
        }
        
        return grouped
    }
    
    // Update selected card based on scroll position
    private func updateSelectedCard(from offset: CGFloat, geometry: GeometryProxy) {
        let cardWidth: CGFloat = 132 // 120 card width + 12 spacing
        
        // Calculate which card is most in view
        let adjustedOffset = -offset
        let cardIndex = Int(round(adjustedOffset / cardWidth))
        let clampedIndex = max(0, min(cardIndex, viewModel.filteredEntries.count - 1))
        
        // Only update if the index actually changed and is valid
        if clampedIndex != selectedCardIndex && clampedIndex < viewModel.filteredEntries.count && clampedIndex >= 0 {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedCardIndex = clampedIndex
                currentForecastEntry = viewModel.filteredEntries[clampedIndex]
            }
        }
    }
    
    private var dayHeaderFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "EEE, MMM d"
        return df
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }
    
    // Check if a date is today
    private func isCurrentDay(_ date: Date) -> Bool {
        let calendar = Calendar.current
        return calendar.isDateInToday(date)
    }
}

// Forecast card component
struct ForecastCard: View {
    let entry: ForecastEntry
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        VStack(spacing: 12) {
            // Time header
            Text(timeFormatter.string(from: entry.dateForecastedFor))
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            // Swell height (main metric)
            VStack(spacing: 4) {
                Text("\(entry.swellHeight, specifier: "%.1f")")
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("m")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Swell period
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.swellPeriod))s")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Wind info
            HStack(spacing: 4) {
                Image(systemName: "wind")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.windSpeed * 3.6)) km/h")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Temperature
            HStack(spacing: 4) {
                Image(systemName: "thermometer")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text("\(Int(entry.temperature))°C")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            // Quality indicator
            HStack(spacing: 4) {
                Image(systemName: "star.fill")
                    .font(.caption)
                    .foregroundColor(qualityColor)
                Text("\(Int(entry.directionQuality * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 120, height: 180)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(isSelected ? Color.blue.opacity(0.1) : Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 2)
                )
        )
        .onTapGesture {
            onTap()
        }
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
        .shadow(color: isSelected ? Color.blue.opacity(0.3) : Color.black.opacity(0.1), radius: isSelected ? 8 : 4, x: 0, y: 2)
    }
    
    private var timeFormatter: DateFormatter {
        let df = DateFormatter()
        df.dateFormat = "HH:mm"
        return df
    }
    
    private var qualityColor: Color {
        let quality = entry.directionQuality
        if quality >= 0.8 { return .green }
        else if quality >= 0.6 { return .yellow }
        else if quality >= 0.4 { return .orange }
        else { return .red }
    }
}

// Preference key for scroll offset
struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}


struct TidePoint: Identifiable {
    let id: UUID
    let time: Date
    let height: Double
    let isHighTide: Bool
}

struct TideChartView: View {
    let tideData: [TidePoint]
    
    var body: some View {
        VStack(alignment: .leading) {
            Text("Tide").font(.headline)
            
            Chart {
                ForEach(tideData) { point in
                    LineMark(
                        x: .value("Time", point.time),
                        y: .value("Height", point.height)
                    )
                    .foregroundStyle(Color.green)
                    
                    if point.isHighTide {
                        PointMark(
                            x: .value("Time", point.time),
                            y: .value("Height", point.height)
                        )
                        .foregroundStyle(Color.green)
                        .annotation {
                            Text("\(point.height, specifier: "%.1f")m")
                                .font(.caption)
                        }
                    }
                }
            }
        }
    }
}
